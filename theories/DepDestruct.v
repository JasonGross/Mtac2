From Mtac2 Require Import Logic Datatypes List Base Tactics ImportedTactics.
Import M.notations.

Require Import Strings.String.
Import Mtac2.List.ListNotations.

(** This is the [abs] from [MetaCoq] but first reducing the variable
    [x] (in case it is [id x] or some convertible term to a variable)
    *)
Definition abs {A} {P} (x:A) (t:P x) :=
  (* let y := reduce RedHNF x in *)
  (* abs_fun y t. *)
  M.abs_fun x t.

Notation redMatch := (reduce (RedWhd [rl:RedMatch])).

(** [match_eq E P A] takes an equality of [T = S] and an element [A]
    of type [T], and returns [A] casted to [P S], but without any match
    (it reduces it). *)
Notation match_eq E P A :=
  (redMatch match E in _ = R return P R with eq_refl => A end).

(** A polymorphic function that returns the type of an element. *)
Definition type_of {A : Type} (x : A) : Type := A.


(** Types that can hold either a [Prop] or a [Type] *)
Section Sorts.

Inductive Sort : Type := SProp | SType.

(** Creates a fresh type according to [s] *)
Definition stype_of (s : Sort) : Type :=
  match s with SType => Type | SProp => Prop end.
Arguments stype_of !_ : simpl nomatch.

(** When working with a sort [s], we cannot simply say "we have an
    element of [stype_of s]". For that, we make [selem_of T], where
    [T] is a [stype_of s]. *)
Definition selem_of {s : Sort} (x : stype_of s) : Type :=
  match s return stype_of s -> Type with
  | SType => fun x => x
  | SProp => fun x => x
  end x.
Arguments selem_of {!_} _ : simpl nomatch.

Fail Example CannotMakeAnElementOfaSort s (P : stype_of s) (x : P) := x.

Example WeCanWithElemOf s (P : stype_of s) (x : selem_of P) := x.


Definition ForAll
            {sort : Sort} {A : Type} :
  (A -> stype_of sort) -> stype_of sort :=
  match
    sort as sort'
    return ((A -> stype_of sort') -> stype_of sort')
  with
  | SProp => fun F => forall a : A, F a
  | SType => fun F => forall a : A, F a
  end.

Definition Fun {sort} {A : Type} :
  forall {F : A -> stype_of sort}, (forall a, selem_of (F a)) -> selem_of (ForAll F) :=
  match sort as sort' return
        forall {F : A -> stype_of sort'}, (forall a, selem_of (F a)) -> selem_of (ForAll F)
  with
  | SProp => fun _ f => f
  | SType => fun _ f => f
  end.

Definition App {sort} {A : Type} : forall {F : A -> _},  selem_of (ForAll (sort := sort) F) -> forall a, selem_of (F a) :=
  match sort as sort' return forall F, selem_of (ForAll (sort := sort') F) -> forall a, selem_of (F a) with
  | SProp => fun F f a => f a
  | SType => fun F f a => f a
  end.
End Sorts.

(** [ITele s] described a sorted type [forall x, ..., y, P] with
    [P] a [stype_of s]. *)
Inductive ITele (sort : Sort) : Type :=
| iBase : stype_of sort -> ITele sort
| iTele : forall {T : Type}, (T -> ITele sort) -> ITele sort.

Delimit Scope ITele_scope with IT.
Bind Scope ITele_scope with ITele.
Arguments iBase {_} _.
Arguments iTele {_ _%type} _.

(** [ATele it] describes a applied version of the type described in
    [it]. For instance, if [it] represents the type [T] equals to
    [forall x, ..., y, P], [ATele it] represents [T c1 ... cn]. *)
(* Inductive ATele {sort} : ITele sort -> Type := *)
(* | aBase : forall {T: stype_of sort}, ATele (iBase T) *)
(* | aTele : forall {T : Type} {f : T -> ITele sort} (a:T), ATele (f a) -> ATele (iTele f). *)

(* Delimit Scope ATele_scope with AT. *)
(* Bind Scope ATele_scope with ATele. *)
(* Arguments aBase {_ _}. *)
(* Arguments aTele {_ _%type _} _%AT _. *)

Fixpoint ATele {sort} (it : ITele sort) : Type :=
  match it with
  | iBase T => unit
  | @iTele _ T f => { t : T & ATele (f t) }
  end.
Arguments ATele {_} !_%IT : simpl nomatch.
Delimit Scope ATele_scope with AT.
Bind Scope ATele_scope with ATele.
Definition aBase {isort} {T} : ATele (@iBase isort T) := tt.
Definition aTele {isort} {T} {f} t (a : ATele (f t)) : ATele (@iTele isort T f)
     := existT _ t a.

(** Returns the type resulting from the [ATele] [args] *)
Fixpoint ITele_App {isort} {it : ITele isort} : forall (args : ATele it), stype_of isort :=
  match it with
  | iBase T => fun _ => T
  | iTele f => fun '(existT _ t a) => ITele_App a
  end.
Arguments ITele_App {_ !_%IT} !_%AT : simpl nomatch.

(** Represents a constructor of an inductive type. *)
Inductive CTele {sort} (it : ITele sort) : Type :=
| cBase : forall {a : ATele it} (c : selem_of (ITele_App a)), CTele it
| cProd : forall {T : Type}, (T -> CTele it) -> CTele it.
Delimit Scope CTele_scope with CT.
Bind Scope CTele_scope with CTele.
Arguments CTele {_} _%IT.
Arguments cBase {_ _%IT} _%AT _.
Arguments cProd {_ _%IT _%type} _.


(** Represents a constructor of an inductive type where all arguments are non-dependent *)
Notation NDCfold it := (fun l =>
                        fold_right (fun T b => T * b)%type unit l -> {a : ATele it & selem_of (ITele_App a)}).
Definition NDCTele {sort} (it : ITele sort) : Type :=
  { l : list Type & NDCfold it l }.

Definition ndcBase {sort} {T : stype_of sort} (a : ATele (iBase T)) (t : selem_of T) : NDCTele (iBase T) := existT _ [m:] (fun _ => existT _ a t).

(** Represents the result type of a branch. *)
(* Inductive RTele {isort} rsort : ITele isort -> Type := *)
(* | rBase : forall {T : stype_of isort}, (selem_of T -> stype_of rsort) -> RTele rsort (iBase T) *)
(* | rTele : forall {T:Type} {f}, (forall (t : T), RTele rsort (f t)) -> RTele rsort (iTele f). *)
(* Delimit Scope RTele_scope with RT. *)
(* Bind Scope RTele_scope with RTele. *)

(* Represent it as a function as its shape is completely determined by the given ITele *)
Fixpoint RTele {isort} rsort (it : ITele isort) : Type :=
  match it with
  | iBase T => selem_of T -> stype_of rsort
  | iTele f => forall t, RTele rsort (f t)
  end.
Arguments RTele {_} _ _%IT.

Fixpoint RTele_App {isort rsort} {it : ITele isort} : forall (a : ATele it), RTele rsort it -> selem_of (ITele_App a) -> stype_of rsort :=
  match it as it' with
  | iBase _ => fun _ rt => rt
  | iTele f => fun '(existT _ t a) rt => RTele_App a (rt t)
  end.

(* Fixpoint RTele_App {isort rsort} {it : ITele isort} (rt : RTele rsort it) : forall (a : ATele it), selem_of (ITele_App a) -> stype_of rsort := *)
(*   match rt in RTele _ it' return forall a' : ATele it', selem_of (ITele_App a') -> stype_of rsort *)
(*   with *)
(*   | @rBase _ _ T t => *)
(*     fun (a : ATele (iBase T)) => *)
(*       match a as a' in ATele it' return *)
(*             match it' with *)
(*             | iBase T' => (selem_of T' -> stype_of rsort) -> selem_of (ITele_App a') -> stype_of rsort *)
(*             | iTele f => True *)
(*             end *)
(*       with *)
(*       | aBase => fun f => f *)
(*       | aTele _ _ => I *)
(*       end t *)
(*   | rTele r => *)
(*     let rec t := RTele_App (r t) in *)
(*     fun (a : ATele (iTele _)) => *)
(*       match a as a' in ATele it' return *)
(*             match it' with *)
(*             | iBase _ => True *)
(*             | @iTele _ T' f => (forall (t:T') (a:ATele (f t)), selem_of (ITele_App a) -> _) -> selem_of (ITele_App a') -> stype_of rsort *)
(*             end *)
(*       with *)
(*       | aBase => I *)
(*       | aTele v a => fun rec => rec v a *)
(*       end rec *)
(*   end. *)

(* rt_T_weird1 and rt_T_weird2 will be equal to
    rt_T_type1 and rt_T_type2.
    Again, Coq does not realize that. So we leave them in for now.
  *)
Fixpoint RTele_Type {isort rsort} {it : ITele isort} : RTele rsort it -> Type :=
match it with
| iBase s => fun _ =>
  (forall (t : selem_of s), stype_of rsort)
| iTele _ => fun rt => forall t, RTele_Type (rt t)
end.

(* No idea why we still need rt_F_max_weird. *)
Fixpoint RTele_Fun {isort rsort} {it : ITele isort} : forall (rt : RTele rsort it), RTele_Type rt :=
  match it with
  | iBase _ => fun r => r
  | iTele _ => fun rt t => (RTele_Fun (rt t))
  end.

Notation reduce_novars := (reduce (RedStrong [rl:RedBeta;RedMatch;RedFix;RedDeltaC;RedZeta])).

(* We need to handle Prop (maybe) *)
Fixpoint abstract_goal {isort} {rsort} {it : ITele isort} (G : stype_of rsort) : forall (args : ATele it) ,
  selem_of (ITele_App args) -> M (RTele rsort it) :=
  match it as it' return forall (a' : ATele it'), selem_of (ITele_App a') -> M (RTele rsort it') with
  | iBase T => fun _ => fun t : selem_of T =>
    let t := reduce_novars t in
    b <- M.is_var t;
    if b then
      let Gty := reduce RedHNF (type_of G) in
      let T' := reduce RedHNF (type_of t) in
      r <- (@abs T' (fun _=>Gty) t G) : M (RTele _ (iBase _));
      let r := reduce RedHNF (r) in
      M.ret r
    else
      M.failwith "Argument t should be a variable"
  | iTele f => fun '(existT _ v args) => fun t : selem_of (ITele_App _) =>
      r <- abstract_goal G args t;
      let v := reduce_novars v in
      b <- M.is_var v;
      if b then
        let Gty := reduce RedHNF (fun v'=>RTele rsort (f v')) in
        let T' := reduce RedHNF (type_of v) in
        r <- @abs T' Gty v r : M (RTele _ (iTele _));
        let r := reduce RedHNF (r) in
        M.ret r
      else
        M.failwith "All indices need to be variables"
  end%MC.

Fixpoint branch_of_CTele {isort} {rsort} {it : ITele isort} (rt : RTele rsort it) (ct : CTele it) : stype_of rsort :=
  match ct with
  | cBase a t => RTele_App a rt t
  | cProd f => ForAll (fun t => branch_of_CTele rt (f t))
  end.

Definition branch_of_NDCTele {isort} {rsort} {it : ITele isort} (rt : RTele rsort it) (ct : NDCTele it) : stype_of rsort :=
  (fix rec l :=
     match l as l' return NDCfold it l' -> stype_of rsort with
     | nil => fun f => RTele_App (projT1 (f tt)) rt (projT2 (f tt))
     | cons T l => fun f => ForAll (fun t : T => rec l (fun y => f(t,y)))
     end) (projT1 ct) (projT2 ct).

(* Get exactly `max` many arguments *)
Definition NotEnoughArguments : Exception. exact exception. Qed.
Fixpoint args_of_max (max : nat) : dyn -> M (list dyn) :=
    match max with
    | 0 => fun _ => M.ret [m:]
    | S max => fun d=>
      mmatch d with
      | [? T Q (t : T) (f : T -> Q)] Dyn (f t) =>
         r <- args_of_max max (Dyn f);
         M.ret (app r [m:Dyn t])
      | _ =>
        T <- M.evar Type;
        P <- M.evar (T -> Type);
        f <- M.evar (forall x:T, P x);
        t <- M.evar T;
        let el := rhnf (d.(elem)) in
        b <- M.unify_cumul el (f t) UniCoq;
        if b then
          r <- args_of_max max (Dyn f); M.ret (app r (Dyn t :: nil))
        else
          M.raise NotEnoughArguments
      end
    end%MC.

(** Given a inductive described in [it] and a list of elements [al],
    it returns the [ATele] describing the applied version of [it] with [al]. *)
Program Fixpoint get_ATele {isort} (it : ITele isort) (al : list dyn) {struct al} : M (ATele it) :=
    match it as it', al return M (ATele it') with
    | iBase T, [m:] => M.ret tt
    | iTele f, t_dyn :: al =>
      (* We coerce the type of the element in [t_dyn] to match that expected by f *)
      t <- M.coerce (elem t_dyn);
      r <- get_ATele (f t) al;
      M.ret (existT _ t r)
    | _, _ => M.raise NoPatternMatches
    end.
Definition get_CTele_raw : forall {isort} (it : ITele isort) (nindx : nat) {A : stype_of isort}, selem_of A -> M (CTele it) :=
  fun isort it nindx =>
    mfix2 rec (A : stype_of isort) (a : selem_of A) : M (CTele it) :=
    mmatch A with
    | [? B (F : B -> stype_of isort)] ForAll F =u> [ H ]
        let f := match_eq H selem_of a in
        n <- M.fresh_name "b";
        M.nu n None (fun b : B =>
          r <- rec (F b) (App f b);
          f' <- abs b r;
          M.ret (cProd f'))
    | _ =>
        let A_red := reduce RedHNF A in (* why the reduction here? *)
        args <- args_of_max nindx (Dyn A_red);
        atele <- get_ATele it args;
        a' <- @M.coerce _ (selem_of (ITele_App (isort := isort) atele)) a ;
        M.ret (cBase atele a')
end.

Definition get_CTele :=
  fun {isort} =>
    match isort as sort return forall {it : ITele sort} nindx {A : stype_of sort}, selem_of A -> M (CTele it) with
    | SProp => get_CTele_raw (isort := SProp)
    | SType => get_CTele_raw (isort := SType)
    end.


Definition get_NDCTele_raw : forall {isort} (it : ITele isort) (nindx : nat) {A : stype_of isort}, selem_of A -> M (NDCTele it) :=
  fun isort it nindx =>
    mfix2 rec (A : stype_of isort) (a : selem_of A) : M (NDCTele it) :=
    mmatch A with
    | [? B (F : B -> stype_of isort)] ForAll F =u> [ H ]
        let f := match_eq H selem_of a in
        n <- M.fresh_name "b";
        M.nu n None (fun b : B =>
                      r <- rec (F b) (App f b);
                      let '(existT _ l F) := r in
                      r' <- (M.abs_fun b F) : M (B -> _);
                      M.ret (existT (NDCfold _) (B::l) (fun '(b,x) => r' b x))
                    )
    | _ =>
        let A_red := reduce RedHNF A in (* why the reduction here? *)
        args <- args_of_max nindx (Dyn A_red);
        atele <- get_ATele it args;
        a' <- @M.coerce _ (selem_of (ITele_App (isort := isort) atele)) a ;
        M.ret (existT _ nil (fun _ => existT _ atele a'))
end.

Definition get_NDCTele :=
  fun {isort} =>
    match isort as sort return forall {it : ITele sort} nindx {A : stype_of sort}, selem_of A -> M (NDCTele it) with
    | SProp => get_NDCTele_raw (isort := SProp)
    | SType => get_NDCTele_raw (isort := SType)
    end.


(** Given a goal, it returns its sorted version *)
Definition sort_goal {T : Type} (A : T) : M (sigT stype_of) :=
  mmatch T with
  | Prop => [H] let A_Prop := match_eq H id A in
                M.ret (existT _ SProp A_Prop)
  | Type => [H] let A_Type := match_eq H id A in
                M.ret (existT _ SType A_Type)
  end.

Definition get_ITele : forall {T : Type} (ind : T), M (nat * (sigT ITele)) :=
  mfix2 f (T : _) (ind : _) : M (nat * sigT ITele)%type :=
    mmatch T with
    | [? (A : Type) (F : A -> Type)] forall a, F a => [H]
      let indFun := match_eq H (fun x=>x) ind in
      name <- M.fresh_binder_name T;
      M.nu name None (fun a : A =>
        r <- f (F a) (indFun a);
        let (n, sit) := r in
        let (sort, it) := sit in
        f <- abs a it;
        M.ret (S n, existT _ sort (iTele f)))
    | Prop => [H]
      let indProp := match_eq H (fun x=>x) ind in
      M.ret (0, existT _ SProp (iBase (sort := SProp) indProp))
    | Type => [H]
      let indType := match_eq H (fun x=>x) ind in
      M.ret (0, existT _ (SType) (iBase (sort := SType) indType))
    | Set => [H]
      let indType := match_eq H (fun x=>x) ind in
      M.ret (0, existT _ (SType) (iBase (sort := SType) indType))
    | _ => M.failwith "Impossible ITele"
    end.

Definition get_ind (A : Type) :
  M (nat * sigT (fun s => (ITele s)) * list dyn) :=
  r <- M.constrs A;
  let (indP, constrs) := r in
  sortit <- get_ITele (elem indP) : M (nat * sigT ITele);
  let nindx : nat := fst sortit in
  let (isort, it) := snd sortit in
  M.ret (nindx, existT _ _ it, constrs).

(* Compute ind type ATele *)
Definition get_ind_atele {isort} (it : ITele isort) (nindx : nat) (A : Type) : M (ATele it) :=
  indlist <- args_of_max nindx (Dyn A) : M (list dyn);
  atele <- get_ATele it indlist : M (ATele it);
  M.ret atele.

Import T.notations.
Definition new_destruct {A : Type} (n : A) : tactic := \tactic g =>
    ind <- get_ind A;
      let (nsortit, constrs) := ind in
      let (nindx, sortit) := nsortit in
      let (isort, it) := sortit in
      atele <- get_ind_atele it nindx A;
                 (* Compute CTeles *)
        cts <- M.map (fun c_dyn : dyn =>
                       let (dtype, delem) := c_dyn in
                       ty <- M.evar (stype_of isort);
                       b <- M.unify_cumul ty dtype UniCoq;
                       if b then
                         el <- M.evar (selem_of ty);
                         M.unify_cumul el delem UniCoq;;
                         get_CTele it nindx ty el
                       else
                         M.failwith "Couldn't unify the type of the inductive with the type of the constructor"
                    ) constrs;
                     (* Compute return type RTele *)
        gt <- M.goal_type g;
        rsG <- sort_goal gt;
        let (rsort, sG) := rsG in
        n' <- M.coerce n;
        rt <- abstract_goal sG atele n';
          let sg := reduce RedSimpl (map (
                        fun ct =>
                           (selem_of (branch_of_CTele rt ct))
                                       ) cts) in
          goals <- M.map (fun ty=> r <- M.evar ty; M.ret (Goal r)) sg;
          branches <- M.map M.goal_to_dyn goals;
          let tsg := reduce RedHNF (type_of sg) in
          let rrf := reduce RedSimpl (RTele_Fun rt) in
          let rrt := reduce RedSimpl (RTele_Type rt) in
          let type := reduce RedHNF (type_of n') in
          caseterm <- M.makecase {|
                       case_ind := type;
                       case_val := n';
                       case_return := Dyn rrf;
                       case_branches := branches
                     |};
          let gterm := M.dyn_to_goal caseterm in
          M.unify_or_fail gterm g;;
          let goals' := dreduce (@map) (map (pair tt) goals) in
          M.ret goals'.
