(** Enumerated expressions with BDDs *)

(* This file is part of the FORMULA Library, released under LGPL license.
   Please read the COPYING file packaged in the distribution  *)

(*  ********************************************************************** *)
(** {2 Types} *)
(*  ********************************************************************** *)

type label = string
  (** A label is just a name *)

type typ = [
  `Benum of string
]
  (** A type is just a name *)

type typdef = [
  `Benum of string array
]
  (** An enumerated type is defined by its (ordered) set of labels *)

(** {3 Datatype representing a BDD register of enumerated type} *)

type 'a t = {
  typ: string;
    (** Type of the value (refers to the database, see below) *)
  reg: 'a Reg.t
    (** Value itself *)
}

(** {3 Database} *)

(** We need a global store where we register type names with their type
  definitions, and also an auxiliary table to efficiently associate types to
  labels. *)

class type ['a,'b,'c] env = object
  constraint 'a = [> typ]
  constraint 'b = [> typdef]
  method cudd : 'c Cudd.Man.t
  method typdef_of_typ : string -> 'b
  method typ_of_var : string -> 'a
end

(*  *********************************************************************** *)
(** {2 Constants and Operation(s)} *)
(*  *********************************************************************** *)

val of_label : ('a,'b,'c) #env -> label -> 'c t
  (** Create a register of the type of the label containing the label *)
val is_cst : 'c t -> bool
  (** Does the register contain a constant value ? *)
val to_code : 'c t -> int
  (** Convert a constant register to its value as a code. *)
val to_label : ('a,'b,'c) #env -> 'c t -> label
  (** Convert a constant register to its value as a label. *)
val equal_label : ('a,'b,'c) #env -> 'c t -> label -> 'c Cudd.Bdd.t
  (** Under which condition the register is equal to the label ? *)
val equal : ('a,'b,'c) #env -> 'c t -> 'c t -> 'c Cudd.Bdd.t
  (** Under which condition the 2 registers are equal ? *)
val ite : 'c Cudd.Bdd.t -> 'c t -> 'c t -> 'c t
  (** If-then-else operator. The types of the 2 branches should be the same. *)

(*  *********************************************************************** *)
(** {2 Decomposition in guarded form} *)
(*  *********************************************************************** *)

val guard_of_label : ('a,'b,'c) #env -> 'c t -> label -> 'c Cudd.Bdd.t
  (** Return the guard of the label in the BDD register. *)

val guardlabels : ('a,'b,'c) #env -> 'c t -> ('c Cudd.Bdd.t * label) list
  (** Return the list [g -> label] represented by the BDD register. *)

(*  *********************************************************************** *)
(** {2 Evaluation} *)
(*  *********************************************************************** *)

val cofactor : 'c t -> 'c Cudd.Bdd.t -> 'c t
val restrict : 'c t -> 'c Cudd.Bdd.t -> 'c t
val tdrestrict : 'c t -> 'c Cudd.Bdd.t -> 'c t

(*  ********************************************************************** *)
(** {2 Printing} *)
(*  ********************************************************************** *)

val print : 
  (Format.formatter -> int -> unit) ->
  Format.formatter -> 'c t -> unit
  (** [print f fmt t] prints the register [t] using the formatter
    [fmt] and the function [f] to print BDDs indices. *)
val print_minterm :
  (Format.formatter -> 'c Cudd.Bdd.t -> unit) ->
  ('a,'b,'c) #env -> Format.formatter -> 'c t -> unit
  (** [print_minterm f fmt t] prints the register [t] using the formatter
    [fmt] and the function [f] to convert BDDs indices to
    names. *)

(*  ********************************************************************** *)
(** {2 Internal functions} *)
(*  ********************************************************************** *)

val size_of_typ : ('a,'b,'c) #env -> string -> int
  (** Return the cardinality of a type (the number of its labels) *)
val maxcode_of_typ : ('a,'b,'c) #env -> string -> int
  (** Return the maximal integer corresponding to a label belonging to the
    type. Labels are indeed associated numbers from 0 to this number. *)
val mem_typcode : ('a,'b,'c) #env -> string -> int -> bool
  (** Does the integer code some label of the given type ? *)
val labels_of_typ : ('a,'b,'c) #env -> string -> label array
  (** Return the array of labels defining the type *)
val code_of_label : ('a,'b,'c) #env -> label -> int
  (** Return the code associated to the label *)
val label_of_typcode : ('a,'b,'c) #env -> string -> int -> label
  (** Return the label associated to the given code interpreted as of type the
    given type. *)

module Minterm : sig
  val iter: ('a,'b,'c) #env -> string -> (label -> unit) -> Reg.Minterm.t -> unit
    (** Iter the function on all label of the given type contained in the
      minterm. *)
  val map: ('a,'b,'c) #env -> string -> (label -> 'd) -> Reg.Minterm.t -> 'd list
    (** Apply the function to all label of the given type contained in the
      minterm and return the list of the results. *)
end

val permute : 'c t -> int array -> 'c t
  (** Permutation (scale [Cudd.Bdd.permute]) *)
val vectorcompose : 'c Cudd.Bdd.t array -> 'c t -> 'c t
  (** Composition (scale [Cudd.Bdd.vectorcompose]) *)

