open Yaml

let failures = ref 0

let rec show = function
  | Null -> "Null"
  | Bool b -> Printf.sprintf "Bool %b" b
  | Float f -> Printf.sprintf "Float %h" f
  | String s -> Printf.sprintf "String %S" s
  | Seq l -> "Seq [" ^ String.concat "; " (List.map show l) ^ "]"
  | Map l ->
    "Map ["
    ^ String.concat "; "
        (List.map (fun (k, v) -> Printf.sprintf "%S, %s" k (show v)) l)
    ^ "]"

let fail fmt =
  Printf.ksprintf
    (fun s ->
      incr failures;
      print_string ("FAIL: " ^ s ^ "\n"))
    fmt

(* [s] parses to [expected]. *)
let ok s expected =
  match of_string s with
  | Ok v when v = expected -> ()
  | Ok v -> fail "%S\n  expected %s\n  got      %s" s (show expected) (show v)
  | Error e -> fail "%S\n  expected %s\n  got error: %s" s (show expected) e

(* [s] is rejected. *)
let err s =
  match of_string s with
  | Error _ -> ()
  | Ok v -> fail "%S should not parse (got %s)" s (show v)

(* [v] survives a printing and parsing round trip. *)
let roundtrip v =
  let s = to_string v in
  match of_string s with
  | Ok v' when v' = v -> ()
  | Ok v' -> fail "round trip of %s\n  printed %S\n  got %s" (show v) s (show v')
  | Error e -> fail "round trip of %s\n  printed %S\n  error: %s" (show v) s e

let () =
  (* Scalars. *)
  ok "" Null;
  ok "null" Null;
  ok "~" Null;
  ok "NULL" Null;
  ok "true" (Bool true);
  ok "False" (Bool false);
  ok "42" (Float 42.);
  ok "-1.5" (Float (-1.5));
  ok "2e3" (Float 2000.);
  ok ".inf" (Float infinity);
  ok "-.inf" (Float neg_infinity);
  ok "no" (String "no");
  ok "0x10" (String "0x10");
  ok "1_0" (String "1_0");
  ok "hello world" (String "hello world");
  (match of_string ".nan" with
  | Ok (Float f) when Float.is_nan f -> ()
  | r ->
    fail ".nan: got %s"
      (match r with Ok v -> show v | Error e -> "error: " ^ e));

  (* Block mappings and sequences. *)
  ok "a: 1\nb: 2\n" (Map [ ("a", Float 1.); ("b", Float 2.) ]);
  ok "a:\n  b: 1\n  c: 2\n" (Map [ ("a", Map [ ("b", Float 1.); ("c", Float 2.) ]) ]);
  ok "a:\n" (Map [ ("a", Null) ]);
  ok "- 1\n- 2\n" (Seq [ Float 1.; Float 2. ]);
  ok "a:\n  - 1\n  - 2\n" (Map [ ("a", Seq [ Float 1.; Float 2. ]) ]);
  (* A sequence may sit at the indentation of its key. *)
  ok "a:\n- 1\n- 2\nb: 3\n"
    (Map [ ("a", Seq [ Float 1.; Float 2. ]); ("b", Float 3.) ]);
  (* Compact entries on the dash line. *)
  ok "- name: alice\n  admin: ~\n- name: bob\n"
    (Seq
       [
         Map [ ("name", String "alice"); ("admin", Null) ];
         Map [ ("name", String "bob") ];
       ]);
  ok "- - 1\n  - 2\n- 3\n" (Seq [ Seq [ Float 1.; Float 2. ]; Float 3. ]);
  ok "-\n- 1\n" (Seq [ Null; Float 1. ]);
  ok "- a:\n    b: 1\n" (Seq [ Map [ ("a", Map [ ("b", Float 1.) ]) ] ]);

  (* Flow collections. *)
  ok "[1, 2]" (Seq [ Float 1.; Float 2. ]);
  ok "[]" (Seq []);
  ok "{}" (Map []);
  ok "[1, ]" (Seq [ Float 1. ]);
  ok "{a: 1, b: [2, {c: 3}]}"
    (Map
       [
         ("a", Float 1.);
         ("b", Seq [ Float 2.; Map [ ("c", Float 3.) ] ]);
       ]);
  ok "{a}" (Map [ ("a", Null) ]);
  ok "{a: }" (Map [ ("a", Null) ]);
  ok "a: []\nb: {}\n" (Map [ ("a", Seq []); ("b", Map []) ]);
  ok "a:\n  - [1, 2]\n" (Map [ ("a", Seq [ Seq [ Float 1.; Float 2. ] ]) ]);
  ok "[a b, \"c, d\"]" (Seq [ String "a b"; String "c, d" ]);

  (* Quoting. *)
  ok "a: \"x\\ny\"" (Map [ ("a", String "x\ny") ]);
  ok "a: 'it''s'" (Map [ ("a", String "it's") ]);
  ok "a: \"local#host\"" (Map [ ("a", String "local#host") ]);
  ok "a: \"\\u00e9\\u20ac\"" (Map [ ("a", String "\xc3\xa9\xe2\x82\xac") ]);
  ok "a: \"1\"" (Map [ ("a", String "1") ]);
  ok "a: '~'" (Map [ ("a", String "~") ]);
  ok "\"a b\": 1" (Map [ ("a b", Float 1.) ]);
  ok "a: b:c" (Map [ ("a", String "b:c") ]);

  (* Comments, blank lines and document markers. *)
  ok "# top\na: 1 # trailing\n\n\nb: 2\n" (Map [ ("a", Float 1.); ("b", Float 2.) ]);
  ok "a: '# not a comment'" (Map [ ("a", String "# not a comment") ]);
  ok "---\na: 1\n" (Map [ ("a", Float 1.) ]);
  ok "---\na: 1\n...\n" (Map [ ("a", Float 1.) ]);
  ok "# only a comment\n" Null;
  ok "a: 1\r\nb: 2\r\n" (Map [ ("a", Float 1.); ("b", Float 2.) ]);

  (* Errors. *)
  err "\ta: 1";
  err "a:\n\t b: 1\n";
  err "a: \"unterminated";
  err "a: 'unterminated";
  err "a: [1, 2";
  err "a: {b: 1";
  err "a: [1] 2";
  err "a: |";
  err "a: >";
  err "a: &anchor";
  err "a: *alias";
  err "a: !!str x";
  err "---\na: 1\n---\nb: 2\n";
  err "a: 1\n  b: 2\n";
  err "- 1\nb: 2\n";
  err "a: 1\n- 2\n";
  err "a: \"\\q\"";

  (* Round trips. *)
  List.iter roundtrip
    [
      Null;
      Bool true;
      Bool false;
      Float 0.;
      Float 42.;
      Float (-1.5);
      Float 1e100;
      Float 0.1;
      Float infinity;
      Float neg_infinity;
      String "";
      String "null";
      String "true";
      String "1.5";
      String "a: b";
      String "a:b";
      String "#x";
      String "a #x";
      String " x ";
      String "[1]";
      String "{a}";
      String "- x";
      String "-x";
      String "a\nb";
      String "a\tb";
      String "---";
      String "...";
      String "héllo";
      Seq [];
      Map [];
      Seq [ Null; Bool true; String "x" ];
      Map [ ("", Null); ("a b", Seq []); ("null", Map []) ];
      Seq [ Seq [ Float 1.; Seq [] ]; Map [ ("a", Seq [ Map [ ("b", Null) ] ]) ] ];
      Map
        [
          ( "server",
            Map
              [
                ("host", String "local#host");
                ("ports", Seq [ Float 80.; Float 443. ]);
                ("opts", Map [ ("tls", Bool true) ]);
              ] );
          ( "users",
            Seq
              [
                Map [ ("name", String "alice"); ("admin", Null) ];
                Map [ ("name", String "bob") ];
              ] );
        ];
    ];

  (* Printing looks like idiomatic YAML. *)
  let printed =
    to_string
      (Map
         [
           ("a", Float 1.);
           ("b", Seq [ Float 1.; Map [ ("c", Float 2.); ("d", Float 3.) ] ]);
           ("e", Map [ ("f", Seq []) ]);
         ])
  in
  let expected = "a: 1\nb:\n  - 1\n  - c: 2\n    d: 3\ne:\n  f: []\n" in
  if printed <> expected then
    fail "printing:\n  expected %S\n  got      %S" expected printed;

  if !failures = 0 then print_string "All tests passed\n\n"
  else (
    Printf.printf "%d failure(s)\n" !failures;
    exit 1)

let () =
  List.iter
    (fun f ->
       Printf.printf "Parsing %s...\n\n%!" f;
       match Yaml.of_file f with
       | Ok v -> Printf.printf "%s\n%!" (Yaml.to_string v)
       | Error e ->
         Printf.printf "error: %s\n%!" e;
         exit 1
    ) ["test.yaml"]
