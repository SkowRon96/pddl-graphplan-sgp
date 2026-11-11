
(in-package :domains)

(define (domain miconic)
  (:requirements :strips :equality :typing :conditional-effects :adl)
  ;; poprawka: usunięto :uncertainty -- dziedzina nie ma niepewności (1 świat),
  ;; a wymóg kierował ją do SGP, który nie obsługuje kwantyfikatorów.
  (:types passenger - object
          going_up going_down vip going_nonstop attendant
          conflict_A conflict_B - passenger
          floor - object
		  pion - object
         )

(:predicates 
(origin ?person - passenger ?floor - floor ?strona - pion)
;; entry of ?person is ?floor
;; inertia

(destin ?person - passenger ?floor - floor ?strona - pion)
;; exit of ?person is ?floor
;; inertia

(above ?floor1 - floor  ?floor2 - floor)
;; ?floor2 is located above of ?floor1

(boarded ?person - passenger)
;; true if ?person has boarded the lift

(boarded2 ?person - passenger)
;; true if ?person has boarded the lift2

(served ?person - passenger)
;; true if ?person has alighted as her destination

(lift-at ?floor - floor ?pion - pion)
;; current position of first lift is at ?floor

(lift-at2 ?floor - floor ?pion - pion)
;; current position of second lift is at ?floor

(passenger-at ?person - passenger ?floor - floor ?pion - pion)
;; current position of the passenger

(connected ?floor1 - floor  ?floor2 - floor)
;; ?floor2 is on the same level as ?floor1
)

(:action do_windy
  :parameters (?f - floor ?p - passenger ?s - pion)
  :precondition (and (lift-at ?f ?s)(passenger-at ?p ?f ?s)(not(served ?p))(not(boarded2 ?p) ))
  :effect (boarded ?p) )

(:action z_windy
  :parameters (?f - floor ?p - passenger ?s - pion)
  :precondition (and (lift-at ?f ?s)(boarded ?p))
  :effect (and (passenger-at ?p ?f ?s)(not(boarded ?p))))

(:action do_windy2
  :parameters (?f - floor ?p - passenger ?s - pion)
  :precondition (and (lift-at2 ?f ?s)(passenger-at ?p ?f ?s)(not(served ?p))(not(boarded ?p)) )
  :effect (boarded2 ?p) )

(:action z_windy2
  :parameters (?f - floor ?p - passenger ?s - pion)
  :precondition (and (lift-at2 ?f ?s)(boarded2 ?p))
  :effect (and (passenger-at ?p ?f ?s)(not(boarded2 ?p))))

(:action up
  :parameters (?f1 - floor ?f2 - floor ?s - pion)
  :precondition (and (lift-at ?f1 ?s) (above ?f1 ?f2))
  :effect (and (lift-at ?f2 ?s) (not (lift-at ?f1 ?s))))

(:action down
  :parameters (?f1 - floor ?f2 - floor ?s - pion)
  :precondition (and (lift-at ?f1 ?s) (above ?f2 ?f1))
  :effect (and (lift-at ?f2 ?s) (not (lift-at ?f1 ?s))))

(:action up2
  :parameters (?f1 - floor ?f2 - floor ?s - pion)
  :precondition (and (lift-at2 ?f1 ?s) (above ?f1 ?f2))
  :effect (and (lift-at2 ?f2 ?s) (not (lift-at2 ?f1 ?s))))

(:action down2
  :parameters (?f1 - floor ?f2 - floor ?s - pion)
  :precondition (and (lift-at2 ?f1 ?s) (above ?f2 ?f1))
  :effect (and (lift-at2 ?f2 ?s) (not (lift-at2 ?f1 ?s))))

(:action przejdz
  :parameters (?p - passenger ?f1 - floor ?f2 - floor ?s1 - pion ?s2 - pion)
  :precondition (and (passenger-at ?p ?f1 ?s1)(connected ?f1 ?f2))
  :effect (and (passenger-at ?p ?f2 ?s2) (not (passenger-at ?p ?f1 ?s1))))
  
  (:action przejdz2
  :parameters (?p - passenger ?f1 - floor ?f2 - floor ?s1 - pion ?s2 - pion)
  :precondition (and (passegner-at ?p ?f2 ?s2)(connected ?f2 ?f1))
  :effect (and (passenger-at ?p ?f1 ?s1) (not (passenger-at ?p ?f2 ?s2))))
  
  (:action cel
  :parameters (?p - passenger ?f - floor ?s - pion)
  :precondition (and (destin ?p ?f ?s)(passenger-at ?p ?f ?s))
  :effect (served ?p)
)  
  
)

(define (problem toster)
   (:domain miconic)
   (:objects p0 p1 - passenger
             f0 f1 f2 f02 f12 f22 - floor
			 s0 s1 - pion)


(:init

(not(served p0))
(not(boarded p0))
(not(boarded2 p0))

(not(served p1))
(not(boarded p1))
(not(boarded2 p1))

(above f0 f1)
(above f0 f2)

(above f1 f2)

(above f02 f12)
(above f02 f22)

(above f12 f22)

(connected f1 f12)
(connected f12 f1)

(origin p0 f12 s1)
(destin p0 f0 s0)
;(destin p0 f1 s0)

(origin p1 f0 s0)
(destin p1 f22 s1)

(lift-at f0 s0)
(lift-at2 f02 s1)

(passenger-at p0 f12 s1)
(passenger-at p1 f0 s0)
)

(:goal  
(and (served p1)
(served p0)
))
)


