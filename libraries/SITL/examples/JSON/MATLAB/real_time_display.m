% while stil run, display information



% function real_time_display(state,init_function,physics_function,max_timestep)
try
    pnet('closeall');   % close any connections left open from past runs
catch
    warning('Could not execute pnet mex, trying to compile')
    if ispc % judge whether windows, such as isunix, ismac. if yes return 1
        % running on windows
        mex -O -outdir ../tcp_udp_ip_2.0.6 ../tcp_udp_ip_2.0.6/pnet.c ws2_32.lib -DWIN32
    else
        % running on unix or mac
        mex -O -outdir ../tcp_udp_ip_2.0.6 ../tcp_udp_ip_2.0.6/pnet.c
    end
    try
        pnet('closeall')
    catch
        error('Failed to compile pnet mex file, see tcp_udp_ip_2.0.6/pnet.c for instructions on manual complication')
    end
end

% time
base_rate = 50;
dt = 1/base_rate;
window = 1000;
time = -(window-1)*dt:dt:0;
% time = 0:dt:dt*(window-1);

% fprintf("time is %f\n", time);
pwm1_in = nan(1,window);
pwm2_in = nan(1,window);
pwm3_in = nan(1,window);
pwm4_in = nan(1,window);

% pwm in plot
figure
subplot(4, 1, 1)
hold all
pwm1_in_plot = plot(time, pwm1_in);
xlim([time(1), 0])
ylabel('pwm 1');

subplot(4, 1, 2)
hold all
pwm2_in_plot = plot(time, pwm2_in);
xlim([time(1), 0])
ylabel('pwm 2');

subplot(4, 1, 3)
hold all
pwm3_in_plot = plot(time, pwm3_in);
xlim([time(1), 0])
ylabel('pwm 3');

subplot(4, 1, 4)
hold all
pwm4_in_plot = plot(time, pwm4_in);
xlim([time(1), 0])
ylabel('pwm 4');
xlabel('time (s)')

% init physics
state = init_function(state);

% init UDP connect port
u=pnet('udpsocket', 9002);
pnet(u, 'setwritetimeout', 1);
pnet(u, 'setreadtimeout', 0);

frame_time = tic;       % save current time to frame_time
frame_count = 0;
physics_time_s = 0;
last_SITL_frame = -1;
print_frame_count = 50; % print the fps every x frames
connected = false;
bytes_read = 4 + 4 + 16*2; % 40 very important, can't be small ,will not printf information

while true
    
    % Wait for data
    while true
        in_bytes = pnet(u, 'readpacket', bytes_read);
        if in_bytes>0
            break;
        end
    end

    % if there is another frame waiting, read it straight away
    if in_bytes > bytes_read
        if in_bytes == u.InputBufferSize
            fprintf('Buffer reset\n');
            continue;
        end
        continue;
    end

    % read  in data from AP
    magic = pnet(u, 'read', 1, 'UINT16', 'intel');
    frame_rate = double(pnet(u, 'read', 1, 'UINT16', 'intel'));
    SITL_frame = pnet(u, 'read', 1, 'UINT32', 'intel');
    pwm_in = double(pnet(u, 'read', 16, 'UINT16', 'intel'))';
%     pwm_in = pnet(u, 'read', 16, 'UINT16', 'intel');
    
    % check the magic value is what expect
    if magic ~= 18458
        warning('incorrect magic value')
        continue;
    end

    %Check if the frame is expected order
    if SITL_frame < last_SITL_frame
        % Controller has reset, reset physics also
        state = init_function(state);
        connected = false;
        fprintf('Controller reset\n');
    elseif SITL_frame == last_SITL_frame
        %duplicate frame, skip
        fprintf('Duplicate input frame\n\n');
        continue;
    elseif SITL_frame ~= last_SITL_frame + 1 && connected
        fprintf('Missed %i input frames\n', SITL_frame - last_SITL_frame - 1)
    end
    last_SITL_frame = SITL_frame;
    state.delta_t = min(1/frame_rate, max_timestep);
    physics_time_s = physics_time_s + state.delta_t;

    if ~connected
        % use port -1 to indicate connection to address of last recv pkt
        connected = true;
        [ip, port] = pnet(u, 'gethost');
        fprintf('Connected to %i.%i.%i.%i:%i\n', ip, port);
    end
    
    frame_count =frame_count + 1;

    % do a physics time step
    state = physics_function(pwm_in, state);

    % build structure representing the JSON string to be sent
    JSON.timestamp = physics_time_s;
    JSON.imu.gyro = state.gyro;
    JSON.imu.accel_body = state.accel;
    JSON.position = state.position;
    JSON.attitude = state.attitude;
    JSON.velocity = state.velocity;

    % Report to AP
    pnet(u, 'printf', sprintf('\n%s\n', jsonencode(JSON)));
    pnet(u, 'writepacket');

    pwm1_in = [pwm1_in(2:end), pwm_in(1)];
    pwm2_in = [pwm2_in(2:end), pwm_in(2)];
    pwm3_in = [pwm3_in(2:end), pwm_in(3)];
    pwm4_in = [pwm4_in(2:end), pwm_in(4)];

    set(pwm1_in_plot, 'Xdata', time, 'YData', pwm1_in);drawnow;
    set(pwm2_in_plot, 'Xdata', time, 'YData', pwm2_in);drawnow;
    set(pwm3_in_plot, 'Xdata', time, 'YData', pwm3_in);drawnow;
    set(pwm4_in_plot, 'Xdata', time, 'YData', pwm4_in);drawnow;

    % print a fps and runtime update
    if rem(frame_count, print_frame_count) == 0
        total_time = toc(frame_time);       % read time from tic function that save to frame_time
        frame_time = tic;                   % again save current time to frame_time
        time_ratio = (print_frame_count*state.delta_t)/total_time;
        fprintf('%0.2f fps, %0.2f%% of realtime\n', print_frame_count/total_time, time_ratio*100)
    end
%     axis padded
end

