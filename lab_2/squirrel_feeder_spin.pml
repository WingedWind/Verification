#define MAX_FOOD 3
#define MAX_ABSENCE 3
#define REFILL_DELAY 4

mtype = { idle, dispense, wait_leave };

byte turn = 0; /* 0-env, 1-sensor, 2-controller, 3-actuators, 4-storage */

bool squirrel_here   = false;
bool sensor_present  = false;
byte food_count      = MAX_FOOD;

mtype controller_state = idle;
bool dispense_cmd   = false;

bool motor_on       = false;
bool lamp_on        = false;

bool refill_request = false;
byte absence_timer  = 0;
byte refill_timer   = 0;

active proctype Environment() {
    do
    :: (turn == 0) ->
        atomic {
            if
            :: squirrel_here ->
                squirrel_here = false;
                absence_timer = 0
            :: else ->
                if
                :: absence_timer < MAX_ABSENCE ->
                    absence_timer++;
                    if
                    :: squirrel_here = true
                    :: squirrel_here = false
                    fi
                :: else ->
                    squirrel_here = true
                fi
            fi;

            if
            :: food_count > 0 ->
                refill_request = false;
                refill_timer = 0
            :: else ->
                if
                :: refill_timer < REFILL_DELAY ->
                    refill_timer++;
                    refill_request = false
                :: else ->
                    refill_request = true;
                    refill_timer = 0
                fi
            fi;

            turn = 1
        }
    od
}

active proctype PresenceSensor() {
    do
    :: (turn == 1) ->
        atomic {
            sensor_present = squirrel_here;
            turn = 2
        }
    od
}

active proctype Controller() {
    do
    :: (turn == 2) ->
        atomic {
            if
            :: controller_state == idle && sensor_present && food_count > 0 ->
                controller_state = dispense
            :: controller_state == dispense ->
                controller_state = wait_leave
            :: controller_state == wait_leave && !sensor_present ->
                controller_state = idle
            :: else ->
                skip
            fi;

            dispense_cmd = (controller_state == dispense);
            turn = 3
        }
    od
}

active proctype Actuators() {
    do
    :: (turn == 3) ->
        atomic {
            motor_on = dispense_cmd;
            lamp_on = (food_count == 0);
            turn = 4
        }
    od
}

active proctype Storage() {
    do
    :: (turn == 4) ->
        atomic {
            if
            :: refill_request ->
                food_count = MAX_FOOD;
                refill_request = false
            :: dispense_cmd && food_count > 0 ->
                food_count--
            :: else ->
                skip
            fi;

            turn = 0
        }
    od
}

ltl p0 { []<> (squirrel_here) }

ltl p1 { [] ( ((turn == 2) && sensor_present && (food_count > 0) && (controller_state == idle))
              -> <> (controller_state == dispense) ) }

ltl p2 { [] ( refill_request -> (food_count == 0) ) }

ltl p3 { [] ( (food_count == 0) -> <> (food_count == MAX_FOOD) ) }
