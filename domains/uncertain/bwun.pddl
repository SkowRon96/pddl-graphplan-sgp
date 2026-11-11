(define (domain galuszka1)
  (:requirements :strips :uncertainty :typing :conditional-effects)
  (:predicates (on ?x ?y)
	       (on-table ?x)
	       (clear ?x)
	       (arm-empty)
	       (holding ?x)
	       )
  (:action pick-up
	     :parameters (?ob1)
	     :precondition (and (clear ?ob1) (on-table ?ob1) (arm-empty))
	     :effect
	     (and (not (on-table ?ob1))
		   (not (clear ?ob1))
		   (not (arm-empty))
		   (holding ?ob1)))
  (:action put-down
	     :parameters (?ob)
	     :precondition (holding ?ob)
	     :effect
	     (and (not (holding ?ob))
		   (clear ?ob)
		   (arm-empty)
		   (on-table ?ob)))
  (:action stack
	     :parameters (?sob ?sunderob)
	     :precondition (and (holding ?sob) (clear ?sunderob))
	     :effect
	     (and (not (holding ?sob))
		   (not (clear ?sunderob))
		   (clear ?sob)
		   (arm-empty)
		   (on ?sob ?sunderob)))
  (:action unstack
	     :parameters (?x)
	     :precondition (and (clear ?x) (arm-empty))
	     :effect
	     (and (holding ?x) (not (clear ?x)) (not (arm-empty))
		  (when (on ?x C)
		        (and (clear C) (not (on ?x C)) ) ) 
	          (when (on ?x D)  
		        (and (clear D) (not (on ?x D)) ) ) ))
  )



(define (problem simple2)
    (:domain galuszka1)
  (:objects A B C D)
  (:init (clear A) (clear B) (arm-empty) (on-table C) (on-table D) 
		(or (and (on A C) (on B D) (not(on A D)) (not(on B C)) )
		    (and (not(on A C)) (not(on B D)) (on A D) (on B C) ) )
)
  (:goal (and (on D B) (on-table B) (on A C) (on-table C) ) ))


(define (problem simple3)
    (:domain galuszka1)
  (:objects A B C D)
  (:init (clear A) (clear B) (arm-empty) (on-table C) (on-table D) 
		(or (and (on A C) (on B D) (not(on A D)) (not(on B C)) )
		    (and (not(on A C)) (not(on B D)) (on A D) (on B C) ) )
)
  (:goal (and (on D B) (on-table B) (on A C) (on C D) ) ))

