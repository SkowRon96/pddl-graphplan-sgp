;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; 
;;; The eight-puzzle is a game in which you attempt to move the pieces into a
;;; certain arrangement from some random arrangement.  The board is two
;;; dimensional, and you can only move pieces left, right, up, and down into
;;; an adjacent empty square.
;;;
;;; These problems are all completely impossible for UCPOP.
;;; 
;;;                                 --==>> Marc Friedman, October 1995
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; The board:
;; S1 S2 S3
;; S4 S5 S6
;; S7 S8 S9

;; The goal:
;; P1 P2 P3
;; P4 P5 P6
;; P7 P8 P9


(define (domain eight-puzzle)
  (:requirements :strips :equality :disjunctive-preconditions)
  
  (:constants S1 S2 S3 S4 S5 S6 S7 S8 S9
	      P1 P2 P3 P4 P5 P6 P7 P8 P9)
  (:predicates (adjacent ?x ?y)
	       (at ?p ?s)
	       (solved)
	       (empty ?s))
  
  ;; poprawka: SGP nie obsługuje :domain-axioms. Aksjomat (adjacent ?x ?y)
  ;; opisywał stałe sąsiedztwo pól -- przeniesiony jako fakty do :init problemów.
  ;; Aksjomat (solved) był skrótem 8 faktów (at Pi Si) -- wpisanych wprost do :goal.
  (:action slide
	     :parameters (?piece ?from ?to)
	     :precondition (and
			    (adjacent ?from ?to)
			    (at ?piece ?from)
			    (empty ?to)
			    )
	     :effect (and (empty ?from)
			   (not (empty ?to))
			   (at ?piece ?to)
			   (not (at ?piece ?from)))))

;; 1 2 3         1 2 3
;; 4 5 6  --==>> 4 5 6
;; 7 - 9         7 8 -

(define (problem p8-1)
    (:domain eight-puzzle)
  (:init   (at P1 S1)
	   (at P2 S2)
	   (at P3 S3)
	   (at P4 S4)
	   (at P5 S5)
	   (at P6 S6)
	   (at P7 S7)
	   (at P8 S9)
	   (empty S8)
	   (adjacent S1 S2)
	   (adjacent S1 S4)
	   (adjacent S2 S1)
	   (adjacent S2 S3)
	   (adjacent S2 S5)
	   (adjacent S3 S2)
	   (adjacent S3 S6)
	   (adjacent S4 S1)
	   (adjacent S4 S5)
	   (adjacent S4 S7)
	   (adjacent S5 S4)
	   (adjacent S5 S2)
	   (adjacent S5 S6)
	   (adjacent S5 S8)
	   (adjacent S6 S5)
	   (adjacent S6 S3)
	   (adjacent S6 S9)
	   (adjacent S7 S4)
	   (adjacent S7 S8)
	   (adjacent S8 S7)
	   (adjacent S8 S5)
	   (adjacent S8 S9)
	   (adjacent S9 S8)
	   (adjacent S9 S6))
  (:goal (and (at P1 S1) (at P2 S2) (at P3 S3) (at P4 S4)
	      (at P5 S5) (at P6 S6) (at P7 S7) (at P8 S8))))

;; - 8 7         1 2 3
;; 6 5 4  --==>> 4 5 6
;; 3 2 1         7 8 -

(define (problem p8-2)
    (:domain eight-puzzle)
  (:init   (at P1 S9)
	   (at P2 S8)
	   (at P3 S7)
	   (at P4 S6)
	   (at P5 S5)
	   (at P6 S4)
	   (at P7 S3)
	   (at P8 S2)
	   (empty S1)
	   (adjacent S1 S2)
	   (adjacent S1 S4)
	   (adjacent S2 S1)
	   (adjacent S2 S3)
	   (adjacent S2 S5)
	   (adjacent S3 S2)
	   (adjacent S3 S6)
	   (adjacent S4 S1)
	   (adjacent S4 S5)
	   (adjacent S4 S7)
	   (adjacent S5 S4)
	   (adjacent S5 S2)
	   (adjacent S5 S6)
	   (adjacent S5 S8)
	   (adjacent S6 S5)
	   (adjacent S6 S3)
	   (adjacent S6 S9)
	   (adjacent S7 S4)
	   (adjacent S7 S8)
	   (adjacent S8 S7)
	   (adjacent S8 S5)
	   (adjacent S8 S9)
	   (adjacent S9 S8)
	   (adjacent S9 S6))
  (:goal (and (at P1 S1) (at P2 S2) (at P3 S3) (at P4 S4)
	      (at P5 S5) (at P6 S6) (at P7 S7) (at P8 S8))))

