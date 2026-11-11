;;; ===================================================================
;;; Dziedzina "Chory pacjent" (sick) -- niepewny stan początkowy, plan warunkowy
;;; Źródło: dziedzina SICK z dystrybucji SGP 1.0h (domains/uncertain/sick.pddl);
;;; przykład z artykułu Weld, Anderson, Smith (AAAI-98) o Sensory Graphplan.
;;;
;;; Nie wiadomo, na którą chorobę cierpi pacjent. Lek na złą chorobę jest groźny
;;; (efekt (D) -- "dangerous"), więc nie można leczyć "na ślepo": trzeba najpierw
;;; zbadać pacjenta (stain + inspect, count-white-cells + analyze-blood).
;;; Akcje inspect i analyze-blood są sensoryczne (observes).
;;;
;;;   sick-1        uncertain   choroba I1 może wystąpić albo nie     (2 światy)
;;;   sick-2        oneof       I1, I2 albo brak choroby             (3 światy)
;;;   sick-3-1ill   bez niepewności -- punkt odniesienia             (1 świat)
;;;   sick-3-2ill … sick-3-5ill  oneof z 2…5 chorobami            (2…5 światów)
;;;                 -- seria do badania wpływu liczby światów na czas obliczeń
;;; ===================================================================

(in-package :domains)

;;;Propositions:
;;;
;;;    I   Infected
;;;    B   Blue
;;;    D   Dangerous
;;;
;;;Actions:
;;;    Stain
;;;        eff: (when I B)
;;;
;;;    Inspect
;;;        observe(B)
;;;
;;;    Medicate
;;;        eff: (when I !I)
;;;             (when !I D)
;;;
;;;Initial Conditions:
;;;    w1:       I, !B, !D
;;;    
;;;    w2:       !I, !B, !D
;;;
;;;Goal:
;;;    !I ^ !D    

(define (domain sick-dom)
    (:requirements :conditional-effects)
  ;; Is there a :sensory requirement keyword?
  
  (:action stain
	   :parameters ()
	   :precondition ()
	   :effect (and (when (I1) (B))
			(when (I2) (R))))
  
  (:action inspect
	   :parameters ()
	   :precondition ()
	   :effect (and (observes (B))
			(observes (R))))
	   
	   
  (:action medicate-1
	   :parameters ()
	   :precondition ()
	   :effect (and (when (I1) (not (I1)))
			(when (not (I1)) (D))))
  
  (:action medicate-2
	   :parameters ()
	   :precondition ()
	   :effect (and (when (I2) (not (I2)))
			(when (not (I2)) (D)))))

(define (problem sick-1)
    (:domain sick-dom)
  (:init (not (R)) (not (B))
	 (not (D))
	 (not (I2))
	 (uncertain (I1)))
  (:goal (and (not (I1)) (not (I2)) (not (D)))))

(define (problem sick-2)
    (:domain sick-dom)
  (:init (not (R)) (not (B))
	 (not (D))
	 ;; Patient has either one or the other type of
	 ;; infection, or none at all.
	 (oneof (and (I1) (not (I2)))
		(and (not (I1)) (I2))
		(and (not (I1)) (not (I2)))))
  ;; Make the patient all better
  (:goal (and (not (I1)) (not (I2)) (not (D)))))

;; Solution:  (stain) (inspect) (medicate-if-necessary)




(define (domain sick-dom-2)
    (:requirements :conditional-effects :sensing)
  
  ;; There are 8 different kinds of illnesses.
  (:constants I1 I2 I3 I4 I5)

  ;; We can perform a throat culture.  The culture
  ;; will turn blue, red, or white
  (:action stain
	   :parameters ()
	   :precondition ()
	   :effect (and (when (or (I3) (I4)) (B))
			(when (or (I1) (I2)) (R))
			(when (I5) (W))))
  (:action inspect
	   :parameters ()
	   :precondition ()
	   :effect (and (observes (B))
			(observes (R))
			(observes (W))))
  
  ;; We can take a blood sample.  The result will be whether the 
  ;; patient has a high white cell count.
  (:action count-white-cells
	   :effect (and (when (or (I1) (I3) (I5)) (high-white-cell-count))))

  (:action analyze-blood
	   :effect (observes (high-white-cell-count)))
   
	   
  ;; We can cure any illness, but using the wrong cure is fatal.
  (:action medicate
	   :parameters (?ill)
	   :precondition (object ?ill)
	   :effect (and (when (?ill) (not (?ill)))
			(when (not (?ill)) (D)))))

  

(define (problem sick-3-1ill)
    (:domain sick-dom-2)
  
  (:init (not (R)) (not (B)) (not (W))	; Culture hasn't been done yet
	 (not (high-white-cell-count))	; Blood sample hasn't been taken.

	 ;; The patient has exactly one illness
	 (I1)
	 (not (I2)) (not (I3)) (not (I4)) (not (I5)) 

	 ;; The patient isn't dead yet.
	 (not (D)))
  (:goal (and (not (I1)) (not (I2)) (not (I3)) (not (I4)) (not (I5))
	      (not (D)))))

(define (problem sick-3-2ill)
    (:domain sick-dom-2)
  
  (:init (not (R)) (not (B)) (not (W))	; Culture hasn't been done yet
	 (not (high-white-cell-count))	; Blood sample hasn't been taken.

	 ;; The patient has exactly one illness
	 (oneof (I1) (I2))
	 (not (I3)) (not (I4)) (not (I5)) 

	 ;; The patient isn't dead yet.
	 (not (D)))
  (:goal (and (not (I1)) (not (I2)) (not (I3)) (not (I4)) (not (I5))
	      (not (D)))))

(define (problem sick-3-3ill)
    (:domain sick-dom-2)
  
  (:init (not (R)) (not (B)) (not (W))	; Culture hasn't been done yet
	 (not (high-white-cell-count))	; Blood sample hasn't been taken.

	 ;; The patient has exactly one illness
	 (oneof (I1) (I2) (I3))
	 (not (I4)) (not (I5)) 

	 ;; The patient isn't dead yet.
	 (not (D)))
  (:goal (and (not (I1)) (not (I2)) (not (I3)) (not (I4)) (not (I5))
	      (not (D)))))

(define (problem sick-3-4ill)
    (:domain sick-dom-2)
  
  (:init (not (R)) (not (B)) (not (W))	; Culture hasn't been done yet
	 (not (high-white-cell-count))	; Blood sample hasn't been taken.

	 ;; The patient has exactly one illness
	 (oneof (I1) (I2) (I3) (I4))
	 (not (I5)) 

	 ;; The patient isn't dead yet.
	 (not (D)))
  (:goal (and (not (I1)) (not (I2)) (not (I3)) (not (I4)) (not (I5))
	      (not (D)))))

(define (problem sick-3-5ill)
    (:domain sick-dom-2)
  
  (:init (not (R)) (not (B)) (not (W))	; Culture hasn't been done yet
	 (not (high-white-cell-count))	; Blood sample hasn't been taken.

	 ;; The patient has exactly one illness
	 (oneof (I1) (I2) (I3) (I4) (I5))

	 ;; The patient isn't dead yet.
	 (not (D)))
  (:goal (and (not (I1)) (not (I2)) (not (I3)) (not (I4)) (not (I5))
	      (not (D)))))

