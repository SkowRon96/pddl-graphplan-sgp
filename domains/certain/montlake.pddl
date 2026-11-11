;; The Montlake bridge is broken.  They keep taking the pin out manually.
;; I have written a domain in its honor.

(define (domain montlake)
  (:requirements :strips :typing :conditional-effects :disjunctive-preconditions)
  ;; poprawka: dodane :typing -- bez niego SGP nie wiąże parametru ?there akcji
  ;; joe-moves (nie występuje w warunku stosowalności), więc Joe nie mógł się ruszyć.

  (:predicates (semaphore ?color)
	       (first-gates-up)
	       (second-gates-up)
	       (all-gates-up)
	       (all-gates-down)
	       (bridge-up)
	       (boats-waiting)
	       (pin-in)
	       (joe-at ?place))

  (:constants red yellow green 
	      tower pin landing)

  ;; poprawka: switch-semaphore z trzema efektami warunkowymi rozbity na trzy
  ;; akcje o tym samym działaniu -- SGP nie znajdował planu, w którym ta sama akcja
  ;; jest użyta kolejno z różnymi efektami warunkowymi.
  (:action switch-semaphore-red-green
	     :parameters ()
	     :precondition (and (semaphore red) (first-gates-up) (second-gates-up))
	     :effect (and (not (semaphore red)) (semaphore green)))
  (:action switch-semaphore-green-yellow
	     :parameters ()
	     :precondition (semaphore green)
	     :effect (and (not (semaphore green)) (semaphore yellow)))
  (:action switch-semaphore-yellow-red
	     :parameters ()
	     :precondition (semaphore yellow)
	     :effect (and (not (semaphore yellow)) (semaphore red)))
  (:action shut-first-gates
	     :parameters ()
	     :precondition (semaphore red)
	     :effect (not (first-gates-up))
	     )
  (:action shut-second-gates
	     :parameters ()
	     :precondition (not (first-gates-up))
	     :effect (not (second-gates-up))
	     )
  (:action open-first-gates
	     :parameters ()
	     :precondition (second-gates-up)
	     :effect (first-gates-up)
	     )
  (:action open-second-gates
	     :parameters ()
	     :precondition (and (pin-in)
				 (joe-at tower))
	     :effect (second-gates-up)
	     )
  (:action pull-pin
	     :parameters ()
	     :precondition (and (not (first-gates-up)) (not (second-gates-up)) ; poprawka: było (all-gates-down)
				 
				 (joe-at pin))
	     :effect (not (pin-in))
	     )
  (:action push-pin
	     :parameters ()
	     :precondition (and (not (first-gates-up)) (not (second-gates-up)) ; poprawka: było (all-gates-down)
				 
				   (joe-at pin))
	     :effect (pin-in)
	     )
  (:action joe-moves
	     :parameters (?here ?there)
	     :precondition (joe-at ?here)
	     :effect (and (not (joe-at ?here))
			   (joe-at ?there))
	     )
  (:action open-bridge
	     :parameters ()
	     :precondition (and (not (first-gates-up)) (not (second-gates-up)) ; poprawka: było (all-gates-down)
				 
				 (not (pin-in))
				 (or (joe-at tower)
				      (joe-at landing)))
	     :effect (and (bridge-up)
			   (not (boats-waiting)))
	     )
  (:action close-bridge
	     :parameters ()
	     :effect (not (bridge-up))
	     )
  ;; poprawka: SGP nie obsługuje :domain-axioms. Aksjomaty (all-gates-up) i
  ;; (all-gates-down) były skrótami koniunkcji (first-gates-up)/(second-gates-up)
  ;; -- wstawione wprost do warunków akcji.
    )

(define (problem bridge)
  (:domain montlake)
  (:init (joe-at tower)
	 (first-gates-up)
	 (second-gates-up)
	 (pin-in)
	 (boats-waiting)
	 (semaphore green))
  (:goal (and (not (boats-waiting))
	      (semaphore green))))
