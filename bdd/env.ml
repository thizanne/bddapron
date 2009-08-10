(** Normalized managers/environments *)

(* This file is part of the BDDAPRON Library, released under LGPL license.
   Please read the COPYING file packaged in the distribution  *)

open Format

(*  ********************************************************************** *)
(** {2 Datatypes } *)
(*  ********************************************************************** *)

exception Bddindex

(** Type defintion *)
type typdef = [
  | `Benum of string array
]

(** Types *)
type typ = [
  | `Bool
  | `Bint of (bool * int)
  | `Benum of string
]

(** (Internal type:) Expressions *)
type 'a expr = [
  | `Bool of 'a Cudd.Bdd.t
      (** Boolean *)
  | `Bint of 'a Int.t
      (** Bounded integer *)
  | `Benum of 'a Enum.t
      (** Enumerated *)
]

type ('a,'b,'c,'d) t0 = ('a,'b,'c,'d) Enum.env0 = {
  cudd : 'c Cudd.Man.t;
    (** CUDD manager *)
  mutable typdef : (string, 'b) PMappe.t;
    (** Named types definitions *)
  mutable vartyp : (string, 'a) PMappe.t;
    (** Associate to a var/label its type *)
  mutable bddindex0 : int;
    (** First index for finite-type variables *)
  mutable bddsize : int;
    (** Number of indices dedicated to finite-type variables *)
  mutable bddindex : int;
    (** Next free index in BDDs used by [self#add_var]. *)
  bddincr : int;
    (** Increment used by [self#add_var] for incrementing
	[self#_bddindex] *)
  mutable idcondvar : (int, string) PMappe.t;
    (** Associates to a BDD index the variable involved by it *)
  mutable vartid : (string, int array) PMappe.t;
    (** (Sorted) array of BDD indices associated to finite-type variables. *)
  mutable varset : (string, 'c Cudd.Bdd.t) PMappe.t;
    (** Associates to enumerated variable the (care)set of
	possibled values. *)
  mutable print_external_idcondb : Format.formatter -> int*bool -> unit;
    (** Printing conditions not managed by the environment..
	By default, [pp_print_int]. *)
  mutable ext : 'd;
  copy_ext : 'd -> 'd;
}

let compare_idb (id1,b1) (id2,b2) =
  let res = id1-id2 in
  if res!=0 then
    res
  else
    (if b1 then 1 else 0) - (if b2 then 1 else 0)

let print_typ (fmt:Format.formatter) typ = match typ with
  | `Bool -> pp_print_string fmt "bool"
  | `Bint(sign,size) -> fprintf fmt "bint(%b,%i)" sign size
  | `Benum s -> pp_print_string fmt s
  | _ -> pp_print_string fmt "Bdd.Env.print_typ: unknown type"
	
let print_typdef (fmt:Format.formatter) typdef = match typdef with
  | `Benum array ->
      fprintf fmt "benum{%a}"
	(Print.array ~first:"" ~sep:"," ~last:"" pp_print_string)
	array
  | _ -> pp_print_string fmt "Bdd.Env.print_typdef: unknown type definition"
      
let print_tid (fmt:Format.formatter) (tid:int array) : unit =
  Print.array Format.pp_print_int fmt tid

module O = struct
  type ('a,'b,'c,'d) t = ('a,'b,'c,'d) t0
  constraint 'a = [>typ]
  constraint 'b = [>typdef]

  let print print_typ print_typdef print_ext fmt (env:('a,'b,'c,'d) t) =
    fprintf fmt
      "{@[<v>typdef = %a;@ vartyp = %a;@ bddindex0 = %i;@ bddindex = %i; bddincr = %i;@ idcondvar = %a;@ vartid = %a;@ ext = %a@]}"
      (PMappe.print pp_print_string print_typdef) env.typdef
      (PMappe.print ~first:"[@[" pp_print_string print_typ) env.vartyp
      env.bddindex0 env.bddindex env.bddincr
      (PMappe.print pp_print_int pp_print_string) env.idcondvar
      (PMappe.print pp_print_string print_tid) env.vartid
      print_ext env.ext
      
  let make
      ?(bddindex0=0)
      ?(bddsize=100)
      ?(relational=false)
      (cudd:'c Cudd.Man.t)
      (ext:'d)
      (copy_ext:'d -> 'd)
      :
      ('a,'b,'c,'d) t
      =
    {
      cudd = cudd;
      typdef = PMappe.empty String.compare;
      vartyp = PMappe.empty String.compare;
      bddindex0 = bddindex0;
      bddsize = bddsize;
      bddindex = bddindex0;
      bddincr = if relational then 2 else 1;
      idcondvar = PMappe.empty (-);
      vartid = PMappe.empty String.compare;
      varset = PMappe.empty String.compare;
      print_external_idcondb =
	begin fun fmt (id,b) ->
	  fprintf fmt "%s%i" (if b then "not " else "") id
	end;
      ext = ext;
      copy_ext = copy_ext;
    }
      
end

type 'c t = (typ,typdef,'c,unit) O.t

(*  ********************************************************************** *)
(** {2 Printing} *)
(*  ********************************************************************** *)

let typ_of_var env (label:string) : 'a
    =
  try
    PMappe.find label env.vartyp
  with Not_found ->
    failwith ("Bdd.Env.typ_of_var: unknwon label/variable "^label)

let print_idcondb env fmt ((id,b) as idb) =
  try
    let var = PMappe.find id env.idcondvar in
    let tid = PMappe.find var env.vartid in
    begin match typ_of_var env var with
    | `Bool -> pp_print_string fmt var
    | _ ->
	begin
	  try
	    for i=0 to pred(Array.length tid) do
	      if id = tid.(i) then begin
		fprintf fmt "%s%i" var i;
		raise Exit
	      end
	    done;
	  with Exit -> ()
	end;
    end
  with Not_found ->
    env.print_external_idcondb fmt idb

let print_order env (fmt:Format.formatter) : unit
    =
  let cudd = env.cudd in
  let nb = Cudd.Man.get_bddvar_nb env.cudd in
  let tab =
    Array.init nb
      (begin fun var ->
	let level = Cudd.Man.level_of_var cudd var in
	(var,level)
      end)
  in
  Array.sort (fun (v1,l1) (v2,l2) -> Pervasives.compare l1 l2) tab;
  Print.array
    ~first:"@[<v>"
    ~sep:"@ "
    ~last:"@]"
    (begin fun fmt (id,level) ->
      fprintf fmt "%3i => %3i, %a"
	level id
	(print_idcondb env) (id,true)
    end)
    fmt
    tab;
  ()

(*  ********************************************************************** *)
(** {2 Constructors} *)
(*  ********************************************************************** *)


let print fmt t = 
  O.print
    print_typ print_typdef (fun fmt _ -> pp_print_string  fmt "_") 
    fmt t

let make ?bddindex0 ?bddsize ?relational cudd = 
  O.make ?bddindex0 ?bddsize ?relational cudd () (fun x -> x)

let copy env =
  { env with
    ext = env.copy_ext env.ext
  }

(*  ********************************************************************** *)
(** {2 Internal functions} *)
(*  ********************************************************************** *)
let permutation env : int array =
    let perm = Array.init (Cudd.Man.get_bddvar_nb env.cudd) (fun i -> i) in
    let index = ref env.bddindex0 in
    PMappe.iter
      (begin fun var tid ->
	Array.iter
	  (begin fun id ->
	    perm.(id) <- !index;
	    index := !index + env.bddincr;
	  end)
	  tid
      end)
      env.vartid
    ;
    perm

let permute_with env (perm:int array) : unit
    =
  env.idcondvar <-
    (PMappe.fold
      (begin fun idcond var res ->
	PMappe.add perm.(idcond) var res
      end)
      env.idcondvar
      (PMappe.empty (-)))
  ;
  env.vartid <-
    (PMappe.map
      (begin fun tid ->
	Array.map (fun id -> perm.(id)) tid
      end)
      env.vartid)
  ;
  env.varset <-
    (PMappe.map
      (begin fun set -> Cudd.Bdd.permute set perm end)
      env.varset)
  ;
  ()

let normalize_with env : int array =
  let perm = permutation env in
  permute_with env perm;
  perm

let add_typ_with (env:('a,'b,'c,'d) O.t) (typ:string) (typdef:'b) : unit
    =
  if PMappe.mem typ env.typdef then
    failwith (sprintf "Bdd.Env.add_typ: type %s already defined" typ)
  ;
  env.typdef <- PMappe.add typ typdef env.typdef;
  begin match typdef with
  | `Benum labels ->
      let t = `Benum typ in
      Array.iter
	(begin fun label -> env.vartyp <- PMappe.add label t env.vartyp end)
	labels
  | _ -> ()
  end

let check_normalized (env:('a,'b,'c,'d) O.t) : bool
    =
  try
    let index = ref env.bddindex0 in
    PMappe.iter
      (begin fun var tid ->
	Array.iter
	  (begin fun id ->
	    if id <> !index then begin
	      printf
		"Bdd.Env.check_normalized: not normalized at index %i@.env=%a@."
		!index
		print env
	      ;
	      raise Exit
	    end;
	    index := !index + env.bddincr;
	  end)
	  tid
      end)
      env.vartid
    ;
    true
  with Exit ->
    false

let permute_expr (expr:'d expr) (permutation:int array) : 'd expr
  =
  match expr with
  | `Bool(x) -> `Bool(Cudd.Bdd.permute x permutation)
  | `Bint(x) -> `Bint(Int.permute x permutation)
  | `Benum(x) -> `Benum(Enum.permute x permutation)

let compose_permutation (perm1:int array) (perm2:int array) : int array =
  let l1 = Array.length perm1 in
  let l2 = Array.length perm2 in
  let l = max l1 l2 in
  let perm = Array.init l (fun i -> i) in
  for i=0 to l1 - 1 do
    let j = perm1.(i) in
    if j<l2 then
      let k = perm2.(j) in
      perm.(i) <- k
  done;
  perm

let compose_opermutation (operm1:int array option) (operm2:int array option)
    :
    int array option
    =
  match operm1 with
  | None -> operm2
  | Some perm1 ->
      match operm2 with
      | None -> operm1
      | Some perm2 ->
	  Some (compose_permutation perm1 perm2)

let permutation_of_offset (length:int) (offset:int) : int array =
  let perm = Array.create length 0 in
  for i=0 to pred length do
    perm.(i) <- i+offset
  done;
  perm

(*  ********************************************************************** *)
(** {2 Accessors} *)
(*  ********************************************************************** *)

let mem_typ env (typ:string) : bool =
  PMappe.mem typ env.typdef
let mem_var env (label:string) : bool =
  PMappe.mem label env.vartyp
let mem_label env (label:string) : bool =
  let typ = PMappe.find label env.vartyp in
  match typ with
  | `Benum _ when not (PMappe.mem label env.vartid) -> true
  | _ -> false

let typdef_of_typ env (typ:string) : 'b
    =
  try
    PMappe.find typ env.typdef
  with Not_found ->
    failwith ("Bdd.Env.t#typdef_of_typ: unknown type "^typ)

let vars env =
  PMappe.maptoset env.vartid

let labels env =
  PMappe.fold
    (begin fun typ def res ->
      match def with
      | `Benum tlabel ->
	  Array.fold_right PSette.add tlabel res
      | _ -> res
    end)
    env.typdef
    (PSette.empty String.compare)

(*  ********************************************************************** *)
(** {2 Adding types and variables} *)
(*  ********************************************************************** *)

let add_var_with env var typ : unit
    =
  if PMappe.mem var env.vartyp then
    failwith (sprintf "Bdd.Env.add_var_with: label/var %s already defined" var)
  ;
  env.vartyp <- PMappe.add var typ env.vartyp;
  begin match typ with
  | #typ as typ ->
      let tid = match typ with
	| `Bool -> [| env.bddindex |]
	| `Bint(b,n) ->
	    Array.init n (fun i -> env.bddindex+(env.bddincr*i))
	| `Benum s ->
	    Array.init
	      (Enum.size_of_typ env s)
	      (fun i -> env.bddindex+(env.bddincr*i))
      in
      if tid<>[||] then begin
	let oldindex = env.bddindex in
	env.bddindex <- env.bddindex + env.bddincr*(Array.length tid);
	Array.iter
	  (fun id -> env.idcondvar <- PMappe.add id var env.idcondvar)
	  tid;
	for i=oldindex to pred(env.bddindex) do
	  ignore (Cudd.Bdd.ithvar env.cudd i)
	done;
      end;
      env.vartid <- PMappe.add var tid env.vartid;
      ()
  | _ ->
      ()
  end;
  if env.bddindex >= env.bddindex0+env.bddsize then raise Bddindex;
  ()

let add_vars_with env lvartyp
    :
    int array option
    =
  let oldindex = env.bddindex in
  List.iter
    (begin fun (var,typ) ->
      add_var_with env var typ
    end)
    lvartyp
  ;
  if oldindex = env.bddindex then
    None
  else
    Some(normalize_with env)

let remove_vars_with env (lvar:string list) : int array option
    =
  let length = ref 0 in
  List.iter
    (begin fun var ->
      let typ = PMappe.find var env.vartyp in
      begin match typ with
      | #typ ->
	  begin try
	    let tid = PMappe.find var env.vartid in
	    env.vartid <- PMappe.remove var env.vartid;
	    length := !length + (Array.length tid)*env.bddincr;
	    Array.iter
	      (fun id -> env.idcondvar <- PMappe.remove id env.idcondvar)
	      tid
	    ;
	    begin match typ with
	    | `Benum _ ->
		env.varset <- PMappe.remove var env.varset
	    | _ -> ()
	    end;
	  with Not_found ->
	    failwith
	      (Format.sprintf
		"Bdd.Env.remove: trying to remove the label %s of an enumerated type"
		var)
	  end
      | _ -> ()
      end;
      env.vartyp <- PMappe.remove var env.vartyp;
    end)
    lvar
  ;
  if !length = 0 then
    None
  else begin
    let perm = normalize_with env in
    env.bddindex <- (env.bddindex - !length);
    Some perm
  end

let rename_vars_with env (lvarvar:(string*string) list)
    :
    int array option
    =
      (* we need to distinguish variables without indices from the
	 other one. *)
  let (lvarvartyptidoset,lvarvartyp) =
    List.fold_left
      (begin fun (res1,res2) (var,nvar) ->
	let typ = PMappe.find var env.vartyp in
	env.vartyp <- PMappe.remove var env.vartyp;
	try
	  let tid = PMappe.find var env.vartid in
	  let oset =
	    try Some (PMappe.find var env.varset)
	    with Not_found -> None
	  in
	  env.vartid <- PMappe.remove var env.vartid;
	  if oset<>None then
	    env.varset <- PMappe.remove var env.varset;
	  Array.iter
	    (begin fun id ->
	      env.idcondvar <- PMappe.remove id env.idcondvar
	    end)
	    tid
	  ;
	  ((var,nvar,typ,tid,oset)::res1,res2)
	with Not_found ->
	  (res1, (var,nvar,typ)::res2)
      end)
      ([],[])
      lvarvar
  in
  List.iter
    (begin fun (var,nvar,typ) ->
      if PMappe.mem nvar env.vartyp then
	failwith
	  (Format.sprintf
	    "Bdd.Env.rename_vars: error, variable %s renamed in already existing %s"
	    var nvar)
      ;
      env.vartyp <- PMappe.add nvar typ env.vartyp;
    end)
    lvarvartyp
  ;
  List.iter
    (begin fun (var,nvar,typ,tid,oset) ->
      if PMappe.mem nvar env.vartyp then
	failwith
	  (Format.sprintf
	    "Bdd.Env.rename_vars: error, variable %s renamed in already existing %s"
	    var nvar)
      ;
      env.vartyp <- PMappe.add nvar typ env.vartyp;
      env.vartid <- PMappe.add nvar tid env.vartid;
      begin match oset with
      | None -> ()
      | Some set -> env.varset <- PMappe.add nvar set env.varset
      end;
      Array.iter
	(begin fun id ->
	  env.idcondvar <- PMappe.add id nvar env.idcondvar
	end)
	tid
      ;
    end)
    lvarvartyptidoset
  ;
  let perm = normalize_with env in
  Some perm

let add_typ env typ typdef =
  let nenv = copy env in
  add_typ_with nenv typ typdef;
  nenv
let add_vars env lvartyp =
  let nenv = copy env in
  ignore (add_vars_with nenv lvartyp);
  nenv
let remove_vars env lvars =
  let nenv = copy env in
  ignore (remove_vars_with nenv lvars);
  nenv
let rename_vars env lvarvar =
  let nenv = copy env in
  ignore (rename_vars_with nenv lvarvar);
  nenv

(* ********************************************************************** *)
(** {2 Operations} *)
(* ********************************************************************** *)

let iter_ordered (env:('a,'b,'c,'d) O.t) (f:(string -> int array -> unit))
  :
  unit
  =
  let processed = ref (PSette.empty String.compare) in
  let size = Cudd.Man.get_bddvar_nb env.cudd in
  for level=0 to size-1 do
    let (id:int) = Cudd.Man.var_of_level env.cudd level in
    try
      let (var:string) = PMappe.find id env.idcondvar in
      if not (PSette.mem var !processed) then begin
	let tid = PMappe.find var env.vartid in
	f var tid;
	processed := PSette.add var !processed;
      end
    with Not_found ->
      ()
  done;
  ()

(* 2 cas pour lesquels not (e1 = e2):

   a) l'ens des variables n'est pas �gal
   ou
   b) bddincr ou bddindex0 est diff�rent

   Peut-�tre faut-il distinguer c'est deux cas ?

   Idem pour l'�galit�
*)

let is_leq env1 env2 : bool =
  env1==env2 ||
    env1.cudd = env2.cudd &&
      env1.bddincr = env2.bddincr &&
      (env1.bddindex - env1.bddindex0 <= env2.bddindex - env2.bddindex0) &&
      (env1.typdef==env2.typdef || PMappe.subset (=) env1.typdef env2.typdef) &&
      (env1.vartyp==env2.vartyp || PMappe.subset (=) env1.vartyp env2.vartyp)

let is_eq env1 env2 : bool =
  env1==(env2) ||
    env1.cudd = env2.cudd &&
      env1.bddincr = env2.bddincr &&
      (env1.bddindex - env1.bddindex0 = env2.bddindex - env2.bddindex0) &&
      (env1.typdef==env2.typdef || PMappe.equal (=) env1.typdef env2.typdef) &&
      (env1.vartyp==env2.vartyp || (PMappe.equal (=) env1.vartyp env2.vartyp))

let shift env (offset:int) : ('a,'b,'c,'d) O.t =
  let perm = permutation_of_offset env.bddindex offset in
  let nenv = copy env in
  nenv.bddindex0 <- env.bddindex0 + offset;
  permute_with nenv perm;
  nenv

let lce env1 env2 : ('a,'b,'c,'d) O.t =
  if is_leq env2 env1 then
    let offset = env1.bddindex0 - env2.bddindex0 in
    if offset>=0 then
      env1
    else
      shift env1 (-offset)
  else if is_leq env1 env2 then
    let offset = env2.bddindex0 - env1.bddindex0 in
    if offset>=0 then
      env2
    else
      shift env2 (-offset)
  else begin
    let typdef =
      PMappe.mergei
	(begin fun typ typdef1 typdef2 ->
	  if typdef1<>typdef2 then
	    failwith
	      (Format.sprintf
		"Bdd.Env.lce: two different definitions for (enumerated) type %s" typ)
	  ;
	  typdef1
	end)
	env1.typdef env2.typdef
    in
    let vartyp =
      PMappe.mergei
	(begin fun var typ1 typ2 ->
	  if typ1<>typ2 then
	    failwith
	      (Format.sprintf
		"Bdd.Env.lce: two different types for label/variable %s" var)
	  ;
	  typ1
	end)
	env1.vartyp env2.vartyp
    in
    let (labeltyp,vartyp) =
      PMappe.partition
	(begin fun varlabel typ ->
	  match typ with
	  | `Benum _ ->
	      not
		((PMappe.mem varlabel env1.vartid) ||
		  (PMappe.mem varlabel env2.vartid))
	  | _ -> false
	end)
	vartyp
    in
    let env = copy env1 in
    env.typdef <- typdef;
    env.vartyp <- labeltyp;
    env.bddindex0 <- Pervasives.max env1.bddindex0 env2.bddindex0;
    env.bddsize <- Pervasives.max env1.bddsize env2.bddsize;
    env.bddindex <- env.bddindex0;
    env.idcondvar <- PMappe.empty (-);
    env.vartid <- PMappe.empty String.compare;
    env.varset <- PMappe.empty String.compare;
    PMappe.iter
      (begin fun var typ ->
	add_var_with env var typ
      end)
      vartyp
    ;
    if not (PMappe.is_empty vartyp) then
      ignore (normalize_with env);
    env
  end

let permutation12 env1 env2 : int array
    =
  assert(
    if is_leq env1 env2 then true
    else begin
      printf "env1=%a@.env2=%a@."
	print env1
	print env2
      ;
      false
    end
  );
  let perm = Array.init (Cudd.Man.get_bddvar_nb env1.cudd) (fun i -> i) in
  let offset = ref (env2.bddindex0 - env1.bddindex0) in
  PMappe.iter
    (begin fun var2 tid2 ->
      try
	let tid1 = PMappe.find var2 env1.vartid in
	Array.iter
	  (fun id -> perm.(id) <- id + !offset)
	  tid1;
      with Not_found ->
	offset := !offset + ((Array.length tid2)*env2.bddincr)
    end)
    env2.vartid
  ;
  perm

let permutation21 env2 env1 : int array
    =
  assert(
    if is_leq env1 env2 then true
    else begin
      printf "env1=%a@.env2=%a@."
	print env1
	print env2
      ;
      false
    end
  );
  let perm = Array.init (Cudd.Man.get_bddvar_nb env2.cudd) (fun i -> i) in
  let offset = ref (env2.bddindex0 - env1.bddindex0) in
  PMappe.iter
    (begin fun var2 tid2 ->
      try
	let tid1 = PMappe.find var2 env1.vartid in
	Array.iter
	  (fun id -> perm.(id + !offset) <- id)
	  tid1;
      with Not_found ->
	offset := !offset + (Array.length tid2)*env2.bddincr;
    end)
    env2.vartid
  ;
  perm

(*  ********************************************************************** *)
(** {2 Precomputing change of environments} *)
(*  ********************************************************************** *)

type 'a change = {
  intro : int array option;
  remove : ('a Cudd.Bdd.t * int array) option;
}

let compute_change env1 env2 =
  let lce = lce env1 env2 in
  let intro =
    if is_eq env1 lce
    then None
    else Some (permutation12 env1 lce)
  in
  let remove =
    if is_eq env2 lce
    then None
    else
      let mapvarid =
	PMappe.diffset
	  lce.vartid
	  (PMappe.maptoset env2.vartid)
      in
      let cudd = env1.cudd in
      let supp = ref (Cudd.Bdd.dtrue cudd) in
      PMappe.iter
	(begin fun var tid ->
	  Array.iter
	    (fun id -> supp := Cudd.Bdd.dand !supp (Cudd.Bdd.ithvar cudd id))
	    tid
	end)
	mapvarid
      ;
      Some(!supp, permutation21 lce env2)
  in
  { intro = intro; remove = remove }

(*  ********************************************************************** *)
(** {2 Utilities} *)
(*  ********************************************************************** *)

type ('a,'b) value = {
  env : 'a;
  val0 : 'b
}

let make_value env val0 =
  assert(
    if (PMappe.cardinal env.idcondvar) =
      ((env.bddindex - env.bddindex0)/env.bddincr)
    then
      check_normalized env
    else begin
      printf "Pb in Bdd.Env.make_value@.";
      printf "env=%a@."
	print env
      ;
      false
    end
  );
  { env=env; val0=val0 }

let extend_environment
    (permute:'a -> int array -> 'a)
    value
    nenv
    =
  if is_eq value.env nenv then
    let offset = nenv.bddindex0 - value.env.bddindex0 in
    if offset=0 then
      value
    else
      let perm = permutation_of_offset value.env.bddindex offset in
      make_value nenv (permute value.val0 perm)
  else if is_leq value.env nenv then
    let perm = permutation12 value.env nenv in
    make_value nenv (permute value.val0 perm)
  else
    failwith "Bdd.Env.extend_environment: the given environment is not a superenvironment "

let check_var (env:('a,'b,'c,'d) O.t) (var:string) : unit =
  try
    let typ = typ_of_var env var in
    let ok =
      match typ with
      | #Enum.typ -> PMappe.mem var env.vartid
      | _ -> true
    in
    if not ok then raise Not_found
  with Not_found ->
    failwith (Format.sprintf "The variable %s is unknown or has a wrong type in the environement of the value" var)

let check_lvar env (lvar:string list) : unit =
  List.iter (check_var env) lvar

let check_value env t =
  if not (
    is_eq env t.env &&
      env.bddindex0 = t.env.bddindex0
  )
  then
    failwith (Print.sprintf "Bdd.Env: value does not have the expected environement@.env=%a@.t.env=%a@." print env print t.env);
  ()

let check_value2 t1 t2 =
  if not (
    is_eq t1.env t2.env &&
      t1.env.bddindex0 = t2.env.bddindex0
  )
  then
    failwith (Print.sprintf "Bdd.Env: operation called with non-equal environments:@.env1=%a@.env2=%a@." print t1.env print t2.env);
  ()

let check_value3 t1 t2 t3 =
  check_value2 t1 t2;
  check_value2 t1 t3

let check_lvarvalue env lvarexpr =
  List.map
    (fun (var,e) ->
      check_var env var;
      check_value env e;
      (var,e.val0)
    )
    lvarexpr

let check_lvalue env lexpr =
  List.map
    (fun e -> check_value env e; e.val0)
    lexpr

let check_ovalue env = function
  | None -> None
  | Some x -> check_value env x; Some x.val0

let mapunop f t =
  make_value t.env (f t.val0)

let mapbinop f t1 t2 =
  check_value2 t1 t2;
  make_value t1.env (f t1.val0 t2.val0)

let mapbinope f t1 t2 =
  check_value2 t1 t2;
  make_value t1.env (f t2.env t1.val0 t2.val0)

let mapterop f t1 t2 t3 =
  check_value3 t1 t2 t3;
  make_value t1.env (f t1.val0 t2.val0 t3.val0)
