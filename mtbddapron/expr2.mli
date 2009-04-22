(** Finite-type and arithmetical expressions paired with condition
    environment *)

(* This file is part of the FORMULA Library, released under LGPL license.
   Please read the COPYING file packaged in the distribution  *)

open Format

(*  ********************************************************************** *)
(** {2 Opened signature} *)
(*  ********************************************************************** *)

module O : sig

  (*  ==================================================================== *)
  (** {3 Boolean expressions} *)
  (*  ==================================================================== *)

  module Bool : sig
    type ('a,'b) t = ('a, 'b Expr1.O.Bool.t) Cond.value
    constraint 'a = (Cond.cond,'b) #Cond.O.t

    val of_expr :
      ('a, ('b, [> `Bool of Expr0.Bool.t ]) Env.value) Cond.value ->
      ('a,'b) t
    val to_expr :
      ('a,'b) t ->
      ('a, ('b, [> `Bool of Expr0.Bool.t ]) Env.value) Cond.value

   val of_expr0 :
     ?normalize:bool -> ?reduce:bool -> ?careset:bool ->
     'b -> 'a -> Expr0.Bool.t -> ('a,'b) t
   val of_expr1 :
     ?normalize:bool -> ?reduce:bool -> ?careset:bool ->
     'a -> 'b Expr1.O.Bool.t -> ('a,'b) t

   val extend_environment : ('a,'b) t -> 'b -> ('a,'b) t
    
   val is_false : ('a,'b) t -> bool
   val is_true : ('a,'b) t -> bool

   val print : Format.formatter -> ('a,'b) t -> unit
  end

  (*  ==================================================================== *)
  (** {3 General expressions} *)
  (*  ==================================================================== *)

  type ('a,'b) t = ('a, 'b Expr1.O.t) Cond.value
  constraint 'a = (Cond.cond,'b) #Cond.O.t

  type ('a,'b) expr = ('a,'b) t

  val of_expr0 :
    ?normalize:bool -> ?reduce:bool -> ?careset:bool ->
    'b -> 'a -> Expr0.t -> ('a,'b) t
  val of_expr1 :
    ?normalize:bool -> ?reduce:bool -> ?careset:bool ->
    'a -> 'b Expr1.O.t -> ('a,'b) t
  val extend_environment : ('a,'b) t -> 'b -> ('a,'b) t  
  val print : Format.formatter -> ('a,'b) t -> unit

  (*  ==================================================================== *)
  (** {3 List of expressions} *)
  (*  ==================================================================== *)

  module List : sig
    type ('a,'b) t = ('a, 'b Expr1.O.List.t) Cond.value
    constraint 'a = (Cond.cond,'b) #Cond.O.t

   val of_lexpr0 :
     ?normalize:bool -> ?reduce:bool -> ?careset:bool ->
     'b -> 'a -> Expr0.t list -> ('a,'b) t
   val of_lexpr1 :
     ?normalize:bool -> ?reduce:bool -> ?careset:bool ->
     'b -> 'a -> 'b Expr1.O.t list -> ('a,'b) t

   val of_listexpr1 :
     ?normalize:bool -> ?reduce:bool -> ?careset:bool ->
     'a -> 'b Expr1.O.List.t -> ('a,'b) t

   val extend_environment : ('a,'b) t -> 'b -> ('a,'b) t
    
   val print : 
     ?first:(unit,Format.formatter,unit) format ->
     ?sep:(unit,Format.formatter,unit) format ->
     ?last:(unit,Format.formatter,unit) format ->
     Format.formatter -> ('a,'b) t -> unit
  end
end

(*  ********************************************************************** *)
(** {2 Closed signature} *)
(*  ********************************************************************** *)

type t = (Cond.t, Expr1.t) Cond.value
type expr = t

val of_expr0 :
  ?normalize:bool -> ?reduce:bool -> ?careset:bool ->
  Env.t -> Cond.t -> Expr0.t -> t
val of_expr1 :
  ?normalize:bool -> ?reduce:bool -> ?careset:bool ->
  Cond.t -> Expr1.t -> t
val extend_environment : t -> Env.t -> t
    
val print : Format.formatter -> t -> unit

module Bool : sig
  type t = (Cond.t, Expr1.Bool.t) Cond.value

  val of_expr : expr -> t
  val to_expr : t -> expr
  val of_expr0 :
    ?normalize:bool -> ?reduce:bool -> ?careset:bool ->
    Env.t -> Cond.t -> Expr0.Bool.t -> t
  val of_expr1 :
    ?normalize:bool -> ?reduce:bool -> ?careset:bool ->
    Cond.t -> Expr1.Bool.t -> t
  val extend_environment : t -> Env.t -> t

  val is_false : t -> bool
  val is_true : t -> bool

  val print : Format.formatter -> t -> unit
end

module List : sig
  type t = (Cond.t, Expr1.List.t) Cond.value

  val of_lexpr0 :
    ?normalize:bool -> ?reduce:bool -> ?careset:bool ->
    Env.t -> Cond.t -> Expr0.t list -> t
  val of_lexpr1 : 
    ?normalize:bool -> ?reduce:bool -> ?careset:bool ->
    Env.t -> Cond.t -> Expr1.t list -> t
  val of_listexpr1 :
    ?normalize:bool -> ?reduce:bool -> ?careset:bool ->
    Cond.t -> Expr1.List.t -> t
  val extend_environment : t -> Env.t -> t
  val print :    
    ?first:(unit,Format.formatter,unit) format ->
    ?sep:(unit,Format.formatter,unit) format ->
    ?last:(unit,Format.formatter,unit) format ->
     Format.formatter -> t -> unit
end