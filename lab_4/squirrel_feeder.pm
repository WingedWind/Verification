dtmc

const int MAX_FOOD = 3;
const int MAX_ABSENCE = 3;
const int REFILL_DELAY = 4;

const double p_appear = 0.2;
const double p_leave  = 0.3;
const double p_fault  = 0.05;

module phase_master
  phase : [0..4] init 0; // 0-env, 1-sense, 2-ctrl, 3-act, 4-store

  [env]   phase=0 -> (phase'=1);
  [sense] phase=1 -> (phase'=2);
  [ctrl]  phase=2 -> (phase'=3);
  [act]   phase=3 -> (phase'=4);
  [store] phase=4 -> (phase'=0);
endmodule

module squirrel_env
  squirrel_present : [0..1] init 0;
  absence_timer    : [0..MAX_ABSENCE] init 0;

  [env] phase=0 & squirrel_present=0 & absence_timer<MAX_ABSENCE ->
      p_appear : (squirrel_present'=1) & (absence_timer'=0)
    + (1-p_appear) : (squirrel_present'=0) & (absence_timer'=absence_timer+1);

  [env] phase=0 & squirrel_present=0 & absence_timer=MAX_ABSENCE ->
      1 : (squirrel_present'=1) & (absence_timer'=0);

  [env] phase=0 & squirrel_present=1 ->
      p_leave : (squirrel_present'=0) & (absence_timer'=1)
    + (1-p_leave) : (squirrel_present'=1) & (absence_timer'=0);
endmodule

module sensor
  sensed_present : [0..1] init 0;

  [sense] phase=1 & squirrel_present=1 ->
      p_fault : (sensed_present'=0)
    + (1-p_fault) : (sensed_present'=1);

  [sense] phase=1 & squirrel_present=0 ->
      p_fault : (sensed_present'=1)
    + (1-p_fault) : (sensed_present'=0);
endmodule

module controller
  state        : [0..2] init 0; // 0 idle, 1 dispense, 2 wait_leave
  dispense_cmd : [0..1] init 0;

  [ctrl] phase=2 & state=0 & sensed_present=1 & food_count>0 ->
      (state'=1) & (dispense_cmd'=1);

  [ctrl] phase=2 & state=1 ->
      (state'=2) & (dispense_cmd'=0);

  [ctrl] phase=2 & state=2 & sensed_present=0 ->
      (state'=0) & (dispense_cmd'=0);

  [ctrl] phase=2 & !((state=0 & sensed_present=1 & food_count>0) | (state=1) | (state=2 & sensed_present=0)) ->
      (state'=state) & (dispense_cmd'=0);
endmodule

module actuators
  motor_on     : [0..1] init 0;
  signal_light : [0..1] init 0;

  [act] phase=3 & food_count=0 ->
      (motor_on'=dispense_cmd) & (signal_light'=1);

  [act] phase=3 & food_count>0 ->
      (motor_on'=dispense_cmd) & (signal_light'=0);
endmodule

module storage
  food_count      : [0..MAX_FOOD] init MAX_FOOD;
  refill_request  : [0..1] init 0;
  refill_timer    : [0..REFILL_DELAY] init 0;

  [env] phase=0 & food_count>0 ->
      (refill_request'=0) & (refill_timer'=0);

  [env] phase=0 & food_count=0 & refill_timer<REFILL_DELAY ->
      (refill_request'=0) & (refill_timer'=refill_timer+1);

  [env] phase=0 & food_count=0 & refill_timer=REFILL_DELAY ->
      (refill_request'=1) & (refill_timer'=0);

  [store] phase=4 & refill_request=1 ->
      (food_count'=MAX_FOOD) & (refill_request'=0) & (refill_timer'=0);

  [store] phase=4 & refill_request=0 & dispense_cmd=1 & food_count>0 ->
      (food_count'=food_count-1);

  [store] phase=4 & !(refill_request=1 | (refill_request=0 & dispense_cmd=1 & food_count>0)) ->
      true;
endmodule

label "squirrel"    = squirrel_present=1;
label "detected"    = sensed_present=1;
label "idle"        = state=0;
label "dispense"    = state=1;
label "empty"       = food_count=0;
label "full"        = food_count=MAX_FOOD;
label "refill_req"  = refill_request=1;
label "ctrl_phase"  = phase=2;
