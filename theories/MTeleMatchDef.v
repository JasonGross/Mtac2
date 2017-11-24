From Mtac2 Require Import Base Logic Datatypes List MTele.
Import M.notations.
Import ListNotations.

Inductive mtpattern A (m : A -> Prop)  : Prop :=
| mtpbase : forall x : A, (m x) -> Unification -> mtpattern A m
| mtptele : forall {C}, (forall x : C, mtpattern A m) -> mtpattern A m.

Arguments mtpbase {A m} _ _ _.
Arguments mtptele {A m C} _.

Definition mtmmatch' A m (y : A) (ps : mlist (mtpattern A (fun x => MTele_ty M (m x)))) : MTele_ty M.t (m y) :=
  MTele_open
    M.t (m y)
    (fun R acc =>
       (fix mmatch' ps : M.t R :=
          match ps with
          | [m:] => M.raise NoPatternMatches
          | p :m: ps' =>
            (* M.print "dbg2";; *)
                    let g := (fix go p :=
                                (* M.print "inner";; *)
                                (* M.print_term p;; *)
                        match p return M.t _ with
                        | mtpbase x f u =>
                          (* M.print "mtpbase";; *)
                          oeq <- M.unify x y u;
                          match oeq return M.t R with
                          | mSome eq =>
                            (* eq has type x = t, but for the pattern we need t = x.
         we still want to provide eq_refl though, so we reduce it *)
                            let h := reduce (RedStrong [rl:RedBeta;RedDelta;RedMatch]) (meq_sym eq) in
                            let 'meq_refl := eq in
                            (* For some reason, we need to return the beta-reduction of the pattern, or some tactic fails *)

                            (* M.print "dbg1";; *)
                            let f' := (match h in _ =m= z return MTele_ty M.t (m z) -> MTele_ty M.t (m y)
                                       with
                                       | meq_refl => fun f => f
                                       end f)
                            in
                            let a := acc _ f' in
                            let b := reduce (RedStrong [rl:RedBeta]) (a) in
                            (* b *)
                            b
                          | mNone =>
                            M.raise DoesNotMatch
                        end

                        | mtptele f =>
                          (* M.print "dbg3";; *)
                          c <- M.evar _;
                          go (f c)
                        end
                     ) in
            (* M.print_term p;; *)
            let t := g p in
            M.mtry' t
                  (fun e =>
                     mif M.unify e DoesNotMatch UniMatchNoRed then mmatch' ps' else M.raise e)
            (* mtry' (open_mtpattern _ (fun _ => _)) *)
            (*       (fun e => *)
            (*          mif unify e DoesNotMatch UniMatchNoRed then mmatch' ps' else raise e) *)
          end) ps
    ).

Module TestFin.
Require Fin.
Definition mt : nat -> MTele := fun n => mTele (fun _ : Fin.t n => mBase (True)).
Definition pO u : mtpattern nat _ := @mtpbase _ (fun x => MTele_ty M (mt x)) O (fun x => Fin.case0 (fun _ => M True) x) u.
Definition p1 u : mtpattern nat _ := @mtpbase _ (fun x => MTele_ty M (mt x)) 1 (fun n => M.ret I) u.
Definition pi u : mtpattern nat (fun x => MTele_ty M (mt x)) :=
  mtptele (fun i : nat =>
             @mtpbase _ _ i (fun n => M.ret I) u
          ).

Program Example pbeta : mtpattern nat (fun x => MTele_ty M (mt x)) :=
  mtptele (fun i : nat =>
            @mtpbase _ (* (fun x => MTele_ty M (mt x)) *) _ (i + 1) (fun n : Fin.t (i + 1) => M.ret I) UniCoq
         ).
End TestFin.