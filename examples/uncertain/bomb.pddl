;;; ===================================================================
;;; Dziedzina "Bomba w toalecie" (bomb in the toilet) -- niepewny stan początkowy
;;; Źródło: dziedzina BT z dystrybucji SGP 1.0h (domains/uncertain/bt.pddl).
;;;
;;; Bomba jest w jednej z paczek, ale nie wiadomo w której. Wrzucenie paczki
;;; do toalety (dunk) rozbraja bombę, jeśli jest w tej paczce.
;;;
;;; Plan odporny (bez sensorów) -- dziedziny bt i bct:
;;;   bt-dd   oneof     bomba w p1 albo w p2                 (2 światy)
;;;   bt-dd2  or        bomba w p1 lub w p2 (lub w obu)      (3 światy)
;;;   bt-dd3  uncertain bomba może być w p1 i może być w p2  (4 światy; brak planu:
;;;                     w świecie bez bomby nie da się jej rozbroić)
;;;   bt-ddd  oneof     3 paczki                             (3 światy)
;;;   bt-mix  oneof + uncertain + or (przykład kombinacji)   (12 światów)
;;;   bct-df2, bct-df3  toaleta się zatyka po każdym dunk -- trzeba spłukiwać
;;;
;;; Plan warunkowy (z sensorem) -- dziedzina bt-sensory-1SA:
;;;   bt-1sa  akcja detect-metal obserwuje (observes) metal w paczce;
;;;           metal jest tylko w paczce z bombą (iff), toaleta zatyka się
;;;           po każdym dunk, więc nie da się zanurzyć wszystkich paczek "na ślepo"
;;; ===================================================================

;;; ----- Plan odporny: dziedzina bt ---------------------------------
(define (domain bt)
  (:requirements :strips :equality :typing :conditional-effects :uncertainty)
  (:action dunk
             :parameters (?p)
             :precondition (and (package ?p) (bomb ?b))           ; Need quant to put this in when
             :effect (when (in ?p ?b)
                       (defused ?b))))

(define (problem bt-dd)              ; graph-plan 1 steps, 2 actions
  (:domain bt)
  (:objects b p1 p2)
  (:init (package p1) (package p2) 
  	 (bomb b)
         (oneof (in p1 b) (in p2 b)))
  (:goal (defused b)))

(define (problem bt-dd2)             ; graph-plan 1 steps, 2 actions 
  (:domain bt)
  (:objects b p1 p2)
  (:init (package p1) (package p2) 
              (bomb b)
              (or (in p1 b) (in p2 b)))
  (:goal (defused b)))

(define (problem bt-dd3)              ; fails, can't defuse when bomb isn't there
  (:domain bt)
  (:objects b p1 p2)
  (:init (package p1) (package p2) 
         (bomb B)
         (uncertain (in p1 b) (in p2 b)))
  (:goal (defused b)))

(define (problem bt-ddd)              ; graph-plan 1 steps, 3 actions
  (:domain bt)
  (:objects b p1 p2 p3)
  (:init (package p1) (package p2) (package p3)
         (bomb b)
         (oneof (in p1 b) (in p2 b) (in p3 b)))
  (:goal (defused b)))

;; Przykład kombinacji operatorów niepewności (nowy, nie ma go w oryginale):
;; oneof -- bomba w p1 albo w p2; uncertain -- może być też w p3;
;; or -- jest w p4 lub w p5 (lub w obu). 12 światów, ale plan odporny ma tylko
;; 2 akcje: oneof gwarantuje bombę w p1 albo p2, więc wystarczy zanurzyć te dwie.
(define (problem bt-mix)
  (:domain bt)
  (:objects b p1 p2 p3 p4 p5)
  (:init (package p1) (package p2) (package p3) (package p4) (package p5)
         (bomb b)
         (oneof (in p1 b) (in p2 b))
         (uncertain (in p3 b))
         (or (in p4 b) (in p5 b)))
  (:goal (defused b)))

;;; ----- Plan odporny: dziedzina bct (zatykająca się toaleta) --------
(define (domain bct)
  (:requirements :strips :equality :typing :conditional-effects :uncertainty)
  (:action dunk
             :parameters (?p)
             :precondition (and (package ?p) (bomb ?b) (not (clogged))) ; Need quant to put this in when
             :effect (and (clogged)
		           (when (in ?p ?b)
		             (defused ?b))))
  (:action flush
             :parameters ()
             :precondition (clogged)
             :effect (not (clogged))))

(define (problem bct-df2)              
  (:domain bct)
  (:objects b p1 p2)
  (:init (package p1) (package p2)
         (bomb B) (not (clogged))
         (oneof (in p1 b) (in p2 b)))
  (:goal (defused b)))

(define (problem bct-df3)              
  (:domain bct)
  (:objects b p1 p2 p3)
  (:init (package p1) (package p2) (package p3)
         (bomb B) (not (clogged))
         (oneof (in p1 b) (in p2 b) (in p3 b)))
  (:goal (defused b)))

;;; ----- Plan warunkowy: dziedzina z akcją sensoryczną ---------------
(define (domain bt-sensory-1SA) (:requirements :typing)
  (:action dunk
	   :parameters (?pkg ?toilet)
	   :precondition (and (toilet ?toilet)
			      (object ?pkg))
	   :effect (and (clogged ?toilet)
			(when (and (in ?pkg)
				   (not (clogged ?toilet)))
			  (not (armed)))))
  
  (:action detect-metal
	   :parameters (?pkg)
	   :precondition (object ?pkg)
	   :effect (observes (metal ?pkg)))
)

(define (problem bt-1sa) (:domain bt-sensory-1SA)
  (:objects pkg1 pkg2 pkg3 pkg4 pkg5 toilet1)
  (:init (not (clogged toilet1))
	 (toilet toilet1)
	 (armed)
	 (oneof (in pkg1) (in pkg2) (in pkg3) (in pkg4) (in pkg5))

	 (iff (in pkg1) (metal pkg1))
	 (iff (in pkg2) (metal pkg2))
	 (iff (in pkg3) (metal pkg3))
	 (iff (in pkg4) (metal pkg4))
	 (iff (in pkg5) (metal pkg5))
	 )

  (:goal (not (armed))))
