;;; ===================================================================
;;; Dziedzina "Gripper" -- przykłady z rozdziału 5 pliku PDDL.pdf
;;; (K. Palenta, "Język zadań planowania PDDL", Politechnika Śląska 2011)
;;;
;;; Robot z chwytakami przenosi piłki między pokojami.
;;;   gripper-strips  -- domena w systemie STRIPS (typy jako predykaty)
;;;   gripper-typed   -- ta sama domena z deklaracją TYPING
;;;
;;; Problemy:
;;;   gripper-1s, gripper-1t -- problem prosty (rozdz. 5.3): 1 piłka, 1 chwytak
;;;   gripper-2              -- problem złożony (rozdz. 5.4): 4 piłki, 3 pokoje, 2 chwytaki
;;; ===================================================================

;;; ----- Domena w systemie STRIPS -----------------------------------
(define (domain gripper-strips)
  (:requirements :strips)

  (:predicates (room ?r)
               (ball ?b)
               (gripper ?g)
               (at-robby ?r)
               (at ?b ?r)
               (free ?g)
               (carry ?o ?g))

  (:action move
      :parameters (?from ?to)
      :precondition (and (room ?from)
                         (room ?to)
                         (at-robby ?from))
      :effect (and (at-robby ?to)
                   (not (at-robby ?from))))

  (:action pick
      :parameters (?obj ?room ?gripper)
      :precondition (and (ball ?obj)
                         (room ?room)
                         (gripper ?gripper)
                         (at ?obj ?room)
                         (at-robby ?room)
                         (free ?gripper))
      :effect (and (carry ?obj ?gripper)
                   (not (at ?obj ?room))
                   (not (free ?gripper))))

  (:action drop
      :parameters (?obj ?room ?gripper)
      :precondition (and (ball ?obj)
                         (room ?room)
                         (gripper ?gripper)
                         (carry ?obj ?gripper)
                         (at-robby ?room))
      :effect (and (at ?obj ?room)
                   (free ?gripper)
                   (not (carry ?obj ?gripper)))))

;;; ----- Domena z deklaracją TYPING ---------------------------------
(define (domain gripper-typed)
  (:requirements :typing)

  (:types room ball gripper)

  (:predicates (at-robby ?r - room)
               (at ?b - ball ?r - room)
               (free ?g - gripper)
               (carry ?o - ball ?g - gripper))

  (:action move
      :parameters (?from ?to - room)
      :precondition (at-robby ?from)
      :effect (and (at-robby ?to)
                   (not (at-robby ?from))))

  (:action pick
      :parameters (?obj - ball ?room - room ?gripper - gripper)
      :precondition (and (at ?obj ?room)
                         (at-robby ?room)
                         (free ?gripper))
      :effect (and (carry ?obj ?gripper)
                   (not (at ?obj ?room))
                   (not (free ?gripper))))

  (:action drop
      :parameters (?obj - ball ?room - room ?gripper - gripper)
      :precondition (and (carry ?obj ?gripper)
                         (at-robby ?room))
      :effect (and (at ?obj ?room)
                   (free ?gripper)
                   (not (carry ?obj ?gripper)))))

;;; ----- Problem prosty 'gripper-1' (rozdz. 5.3) --------------------
;;; Piłka Ball1 ma trafić z pokoju roomA do roomB.

;; wersja STRIPS
(define (problem gripper-1s)
  (:domain gripper-strips)
  (:objects roomA roomB Ball1 arm)
  (:init (room roomA)
         (room roomB)
         (ball Ball1)
         (gripper arm)
         (at-robby roomA)
         (free arm)
         (at Ball1 roomA))
  (:goal (at Ball1 roomB)))

;; wersja TYPING
(define (problem gripper-1t)
  (:domain gripper-typed)
  (:objects roomA roomB - room Ball1 - ball arm - gripper)
  (:init (at-robby roomA)
         (free arm)
         (at Ball1 roomA))
  (:goal (at Ball1 roomB)))

;;; ----- Problem złożony 'gripper-2' (rozdz. 5.4) -------------------
;;; Stan początkowy: Ball1, Ball2 w roomA, Ball3 w roomB, Ball4 w roomC,
;;;                  robot w roomA, oba chwytaki wolne.
;;; Stan docelowy:   Ball1, Ball4 w roomB; Ball2, Ball3 w roomC.
(define (problem gripper-2)
  (:domain gripper-typed)
  (:objects roomA roomB roomC - room
            Ball1 Ball2 Ball3 Ball4 - ball
            left right - gripper)
  (:init (at-robby roomA)
         (free left) (free right)
         (at Ball1 roomA) (at Ball2 roomA)
         (at Ball3 roomB) (at Ball4 roomC))
  (:goal (and (at Ball1 roomB) (at Ball4 roomB)
              (at Ball2 roomC) (at Ball3 roomC))))
