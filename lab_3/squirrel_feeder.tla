--------------------------- MODULE squirrel_feeder ---------------------------
EXTENDS Naturals, TLC

CONSTANTS MAX_FOOD, MAX_ABSENCE, REFILL_DELAY

VARIABLES
    phase,              \* "env", "sensor", "ctrl", "act", "store"
    squirrelHere,       \* BOOLEAN
    sensorPresent,      \* BOOLEAN
    controllerState,    \* "idle", "dispense", "wait_leave"
    dispenseCmd,        \* BOOLEAN
    motorOn,            \* BOOLEAN
    lampOn,             \* BOOLEAN
    foodCount,          \* 0..MAX_FOOD
    absenceTimer,       \* 0..MAX_ABSENCE
    refillRequest,      \* BOOLEAN
    refillTimer         \* 0..REFILL_DELAY

Vars ==
    << phase, squirrelHere, sensorPresent, controllerState, dispenseCmd,
       motorOn, lampOn, foodCount, absenceTimer, refillRequest, refillTimer >>

Init ==
    /\ phase = "env"
    /\ squirrelHere = FALSE
    /\ sensorPresent = FALSE
    /\ controllerState = "idle"
    /\ dispenseCmd = FALSE
    /\ motorOn = FALSE
    /\ lampOn = FALSE
    /\ foodCount = MAX_FOOD
    /\ absenceTimer = 0
    /\ refillRequest = FALSE
    /\ refillTimer = 0

EnvStep ==
    /\ phase = "env"
    /\ IF squirrelHere
          THEN /\ squirrelHere' \in {TRUE, FALSE}
               /\ absenceTimer' = 0
          ELSE /\ IF absenceTimer = MAX_ABSENCE
                    THEN /\ squirrelHere' = TRUE
                         /\ absenceTimer' = 0
                    ELSE /\ squirrelHere' \in {TRUE, FALSE}
                         /\ absenceTimer' =
                               IF squirrelHere' THEN 0 ELSE absenceTimer + 1
    /\ IF foodCount > 0
          THEN /\ refillRequest' = FALSE
               /\ refillTimer' = 0
          ELSE /\ IF refillTimer = REFILL_DELAY
                    THEN /\ refillRequest' = TRUE
                         /\ refillTimer' = 0
                    ELSE /\ refillRequest' = FALSE
                         /\ refillTimer' = refillTimer + 1
    /\ phase' = "sensor"
    /\ UNCHANGED << sensorPresent, controllerState, dispenseCmd, motorOn, lampOn, foodCount >>

SensorStep ==
    /\ phase = "sensor"
    /\ sensorPresent' = squirrelHere
    /\ phase' = "ctrl"
    /\ UNCHANGED << squirrelHere, controllerState, dispenseCmd, motorOn, lampOn,
                    foodCount, absenceTimer, refillRequest, refillTimer >>

ControllerStep ==
    /\ phase = "ctrl"
    /\ LET nextState ==
            IF controllerState = "idle" /\ sensorPresent /\ foodCount > 0
               THEN "dispense"
            ELSE IF controllerState = "dispense"
               THEN "wait_leave"
            ELSE IF controllerState = "wait_leave" /\ ~sensorPresent
               THEN "idle"
            ELSE controllerState
       IN /\ controllerState' = nextState
          /\ dispenseCmd' = (nextState = "dispense")
    /\ phase' = "act"
    /\ UNCHANGED << squirrelHere, sensorPresent, motorOn, lampOn, foodCount,
                    absenceTimer, refillRequest, refillTimer >>

ActuatorStep ==
    /\ phase = "act"
    /\ motorOn' = dispenseCmd
    /\ lampOn' = (foodCount = 0)
    /\ phase' = "store"
    /\ UNCHANGED << squirrelHere, sensorPresent, controllerState, dispenseCmd,
                    foodCount, absenceTimer, refillRequest, refillTimer >>

StorageStep ==
    /\ phase = "store"
    /\ IF refillRequest
          THEN /\ foodCount' = MAX_FOOD
               /\ refillRequest' = FALSE
          ELSE /\ foodCount' =
                    IF dispenseCmd /\ foodCount > 0
                       THEN foodCount - 1
                       ELSE foodCount
               /\ refillRequest' = refillRequest
    /\ phase' = "env"
    /\ UNCHANGED << squirrelHere, sensorPresent, controllerState, dispenseCmd,
                    motorOn, lampOn, absenceTimer, refillTimer >>

Next ==
    EnvStep \/ SensorStep \/ ControllerStep \/ ActuatorStep \/ StorageStep

TypeOK ==
    /\ phase \in {"env", "sensor", "ctrl", "act", "store"}
    /\ squirrelHere \in BOOLEAN
    /\ sensorPresent \in BOOLEAN
    /\ controllerState \in {"idle", "dispense", "wait_leave"}
    /\ dispenseCmd \in BOOLEAN
    /\ motorOn \in BOOLEAN
    /\ lampOn \in BOOLEAN
    /\ foodCount \in 0..MAX_FOOD
    /\ absenceTimer \in 0..MAX_ABSENCE
    /\ refillRequest \in BOOLEAN
    /\ refillTimer \in 0..REFILL_DELAY

Spec == Init /\ [][Next]_Vars /\ WF_Vars(Next)

P1 == []<>(squirrelHere = TRUE)

P2 == []((phase = "ctrl" /\ sensorPresent /\ foodCount > 0 /\ controllerState = "idle")
         => <>(controllerState = "dispense"))

P3 == [](refillRequest => foodCount = 0)

P4 == []((foodCount = 0) => <>(foodCount = MAX_FOOD))

=============================================================================
