let () =
  Array.iter (fun f ->
      Printf.printf "Parsing %s...\n\n%!" f;
      Printf.printf "%s\n\n%!" (Yaml.to_string @@ Result.get @@ Yaml.of_string f)
    ) Sys.argv
