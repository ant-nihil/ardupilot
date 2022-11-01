#pragma once

#include <AP_Common/AP_Common.h>
#include <AP_Param/AP_Param.h>
#include <AP_Logger/AP_Logger.h>
#include <AC_PID/AC_PID.h>

class AP_ADRC : public AC_PID {
    public:
        // Constructor
        AP_ADRC(float B0, float dt);

        CLASS_NO_COPY(AP_ADRC);

        // update_all -set target and measured inputs to ADRC controller and calculate outputs
        // target and error are filtered
        float update_all(float target, float measurement, bool limit = false) override;

        // set time step in seconds
        void set_dt(float dt);

        // reset ESO
        void reset_eso(float measuremenr);

        // reset filter
        void reset_filter() {
            _flags._reset_filter = true;
        }

        const AP_PIDInfo& get_pid_info(void) const override { return _pid_info; }

        // parameter var table
        static const struct AP_Param::GroupInfo var_info[];
    private:
        float fal(float e, float alpha, float delta);

        float sign(float x);

        // parameters
        AP_Float _wc;           // response bandwidth in rad/s
        AP_Float _wo;           // state estimation bandwidth in rad/s
        AP_Float _b0;           // control gain
        AP_Float _limit;
        AP_Float _delta;
        AP_Int8 _order;

        // flags
        struct ap_adrc_flags
        {
            bool reset_filter :1;   // ture when input filter should be reset during next call to set_input
        } _flags;
        
        // internal variables
        float _dt;              //timestep in seconds

        // ESO internal variables
        float _z1;
        float _z2;
        float _z3;

        AP_PIDInfo _pid_info;
}
