library(Rgadget)
library(unittest, quietly = TRUE)
source('utils/helpers.R')

ver_string <- paste("; Generated by Rgadget", packageVersion("Rgadget"))

tempdir <- function() {
    dir <- tempfile()
    dir.create(dir)
    return(dir)
}

# Write string into temporary directory and read it back again as a gadget file
read.gadget.string <- function(..., dir = tempdir(), file_type = "generic") {
    writeLines(c(...), con = file.path(dir, "wibble"))
    read.gadget.file(dir, "wibble", file_type = file_type)
}

# Test we can go from string to object and back again
test_loopback <- function(..., dir = tempdir(), file_type = "generic") {
    file_name <- "loopback"
    writeLines(c(...), con = file.path(dir, file_name))

    gf <- read.gadget.file(dir, file_name, file_type = file_type)
    write.gadget.file(gf, dir)
    ok(cmp(dir_list(dir)[[file_name]], c(...)), paste0(c(...)[[2]], c(...)[[3]]))
}

unattr <- function(x) {
    if(length(names(x)) == 0) {
        attributes(x) <- NULL
    } else if(sum(nchar(names(x))) == 0) {
        # All zero-length names is the same as no names
        attributes(x) <- NULL
    } else {
        attributes(x) <- list(names = names(x))
    }
    return(x)
}

ok_group("Can generate gadgetfile objects", {
    ok(cmp_error(gadgetfile(), "file_name"), "Can't make a gadgetfile without filename")

    ok("gadgetfile" %in% class(gadgetfile("wibble")))
})

ok_group("Can write arbitary data files", {
    dir <- tempfile()

    write.gadget.file(gadgetfile("wobble", components = list(list(
        cabbage = "yes",
        potatoes = c("1 potato", "2 potato", "3 potato", "4!"),
        sprouts = 'Like, "Eeeew!"'))), dir)
    ok(cmp(dir_list(dir), list(
        wobble = c(
            ver_string,
            "cabbage\tyes",
            "potatoes\t1 potato\t2 potato\t3 potato\t4!",
            'sprouts\tLike, "Eeeew!"',
        NULL)
    )), "Wrote out simple gadget file")

    write.gadget.file(gadgetfile("sub/wabble",
        components = list(list(cabbage = "no"))), dir)
    ok(cmp(dir_list(dir), list(
        "sub/wabble" = c(
            ver_string,
            "cabbage\tno",
        NULL),
        wobble = c(
            ver_string,
            "cabbage\tyes",
            "potatoes\t1 potato\t2 potato\t3 potato\t4!",
            'sprouts\tLike, "Eeeew!"',
        NULL)
    )), "Wrote out extra file in subdir")

    write.gadget.file(gadgetfile("sub/wabble", components = list(list(
        cabbage = "ick",
        cauliflower = "yum"))), dir)
    ok(cmp(dir_list(dir), list(
        "sub/wabble" = c(
            ver_string,
            "cabbage\tick",
            "cauliflower\tyum",
        NULL),
        wobble = c(
            ver_string,
            "cabbage\tyes",
            "potatoes\t1 potato\t2 potato\t3 potato\t4!",
            'sprouts\tLike, "Eeeew!"',
        NULL)
    )), "Overwrote a gadget file")

    write.gadget.file(gadgetfile("wobble", components = list(
        list(
            potatoes = list("1 potato", "2 potato", "3 potato", 4, quote(4 + log(2))),
            fish = c(quote(1 + 1), quote(4 + 2 - 8)),
            single = quote(log(8) * log10(2)),
            sprouts = 'No.'),
        data.frame(
            method = c("a", "b"),
            fn = I(list(quote(1 + log(2)), quote(3 + sqrt(4))))))), dir)
    ok(cmp(dir_list(dir), list(
        "sub/wabble" = c(
            ver_string,
            "cabbage\tick",
            "cauliflower\tyum",
        NULL),
        wobble = c(
            ver_string,
            "potatoes\t1 potato\t2 potato\t3 potato\t4\t(+ 4 (log 2))",
            "fish\t(+ 1 1)\t(- (+ 4 2) 8)",
            "single\t(* (log 8) (log10 2))",
            'sprouts\tNo.',
            "; -- data --",
            "; method\tfn",
            "a\t(+ 1 (log 2))",
            "b\t(+ 3 (sqrt 4))",
        NULL)
    )), "Wrote out list as value, including gadget.formulae")

})

ok_group("Can add components and preambles", {
    dir <- tempfile()
    gf <- gadgetfile("wibble",
        components = list(
            structure(list(sprouts = 'Like, "Eeeew!"'), preamble = "Carrots"),
            component = structure(list(name = "component1"), preamble = list("The first component", "I like it")),
            component = structure(list(name = "component2"), preamble = "The second component (with the same name)"),
            tea = structure(list(milk = 1, sugars = 2), preamble = "Tea, please")))
    write.gadget.file(gf, dir)

    ok(cmp(dir_list(dir), list(
        wibble = c(
            ver_string,
            "; Carrots",
            'sprouts\tLike, "Eeeew!"',
            '; The first component',
            '; I like it',
            '[component]',
            'name\tcomponent1',
            '; The second component (with the same name)',
            '[component]',
            'name\tcomponent2',
            '; Tea, please',
            '[tea]',
            'milk\t1',
            'sugars\t2',
        NULL)
    )), "Multiple components with preambles")
})

ok_group("Can include tabular data", {
    dir <- tempfile()
    gf <- gadgetfile("wabble",
        components = list(data.frame(a = c(1,3), b = c(2,5))))
    write.gadget.file(gf, dir)

    ok(cmp(dir_list(dir), list(
        wabble = c(
            ver_string,
            "; -- data --",
            "; a\tb",
            "1\t2",
            "3\t5",
        NULL)
    )), "Tabular data")
})

ok_group("Can nest gadgetfile objects", {
    dir <- tempfile()

    main <- gadgetfile("courses/main",
        components = list(list(cabbage = "yes", potatoes = "2")))
    dessert <- gadgetfile("courses/dessert",
        components = list(list(victoria_sponge = "yes")))
    dinner <- gadgetfile("dinner",
        components = list(list(firstcourse = main, secondcourse = dessert)))

    ok(cmp(capture.output(print(dinner)), c(
        ver_string,
        "firstcourse\tcourses/main",
        "secondcourse\tcourses/dessert",
    NULL)), "Wrote filenames for gadgetfile values")

    write.gadget.file(dinner, dir)
    ok(cmp(dir_list(dir), list(
        "courses/dessert" = c(
            ver_string,
            "victoria_sponge\tyes",
        NULL),
        "courses/main" = c(
            ver_string,
            "cabbage\tyes",
            "potatoes\t2",
        NULL),
        dinner = c(
            ver_string,
            "firstcourse\tcourses/main",
            "secondcourse\tcourses/dessert",
        NULL)
    )), "Wrote out nested gadget files")
})

ok_group("Can read gadget files", {
    ok(cmp_error(read.gadget.file(dir, 'exist/ant'), "exist/ant"),
        "Complain about missing file")
    gf <- read.gadget.file(dir, 'non-exist/ant', missingOkay = TRUE)
    ok(cmp(unattr(gf), list()), "Get an empty gadget file if missingOkay")

    # Basic structure
    gf <- read.gadget.string(
        ver_string,
        "a\t2",
        "b\t4",
        file_type = "generic")
    ok(cmp(
        unattr(gf),
        list(list(a = 2, b = 4))), "Components read")

    # Strings / numbers
    gf <- read.gadget.string(
        ver_string,
        "allnumber\t2\t4\t6\t8",
        "allstring\twho\tdo\twe\tappreciate?",
        "mix\t1\tpotato\t2\tpotato\t3\tpotato\t4!",
        file_type = "generic")
    ok(cmp(
        unattr(gf),
        list(list(
            allnumber = c(2,4,6,8),
            allstring = c("who", "do", "we", "appreciate?"),
            mix = c("1", "potato", "2", "potato", "3", "potato", "4!")))), "Strings/numbers read")

    # Comments and components
    gf <- read.gadget.string(
        ver_string,
        "; This is a comment that should be preserved",
        "a\t6",
        "b\t8",
        "; This is a comment associated with the component below",
        "; So is this",
        "[carrots]",
        "; This is a line preamble",
        "like\tYes-I-do",
        "; Not this",
        "[carrots]",
        "like\tNo thanks",
        file_type = "generic")
    ok(cmp(
        unattr(gf),
        list(
            structure(list(a = 6, b = 8), preamble = list("This is a comment that should be preserved")),
            carrots = structure(
                list(like = structure("Yes-I-do", preamble = list("This is a line preamble"))),
                preamble = list("This is a comment associated with the component below", "So is this")),
            carrots = structure(
                list(like = c("No", "thanks")),
                preamble = list("Not this")))), "Components / preamble read")
    # Make sure they get printed back too
    test_loopback(
        ver_string,
        "; This is a comment that should be preserved",
        "a\t6",
        "b\t8",
        "; This is a comment associated with the component below",
        "; So is this",
        "[carrots]",
        "; This is a line preamble",
        "like\tYes-I-do",
        "; Not this",
        "[carrots]",
        "like\tNo\tthanks",
        file_type = "generic")

    # Data
    gf <- read.gadget.string(
        ver_string,
        "a\t99",
        "; Preamble for data",
        "; -- data --",
        "; col\tcolm\tcolt\tcoal",
        "3\t5\t9\t3",
        "7\t5\t33\t3",
        "3\t2\t9\t4",
        file_type = "generic")
    ok(cmp(unattr(gf), list(
        list(a = 99),
        structure(
            data.frame(col = as.integer(c(3,7,3)), colm = as.integer(c(5,5,2)), colt = as.integer(c(9,33,9)), coal = as.integer(c(3,3,4))),
            preamble = list("Preamble for data")))), "Data with preable")

    # Double data
    gf <- read.gadget.string(
        ver_string,
        "a\t99",
        "; Preamble for data",
        "; -- data --",
        "; col\tcolm\tcolt\tcoal",
        "3\t5\t9\t3",
        "7\t5\t33\t3",
        "3\t2\t9\t4",
        "; -- data --",
        "; a\tb\tc",
        "1\t2\t3",
        "1\t2\t3",
        "1\t2\t3",
        "[final]",
        "moo\tyes",
        file_type = "generic")
    ok(cmp(unattr(gf), list(
        list(a = 99),
        structure(
            data.frame(col = as.integer(c(3,7,3)), colm = as.integer(c(5,5,2)), colt = as.integer(c(9,33,9)), coal = as.integer(c(3,3,4))),
            preamble = list("Preamble for data")),
        data.frame(a = as.integer(c(1,1,1)), b = as.integer(c(2,2,2)), c = as.integer(c(3,3,3))),
        final = list(moo = 'yes'))), "Double data frames")

    # Data with mangled spacing & formulae
    gf <- read.gadget.string(
        ver_string,
        "; -- data --",
        "; col\tcolm\tcolt\tcoal",
        "3    5\t(+ 10 (- #potato 12)\t) 13",
        file_type = "generic")
    ok(cmp(unattr(gf), list(
        data.frame(
            col = as.integer(3),
            colm = as.integer(5),
            colt = I(list(quote(10 + (potato - 12)))),
            coal = as.integer(13)))), "Data with mangled spacing & formulae")

    gf <- read.gadget.string(
        ver_string,
        "; -- data --",
        "; col\tcolm\tcolt\tcoal",
        "3    5\t(+ 10 (- #potato 12)) 13",
        "3    5\t(+ 10 (log #cabbage)) 13",
        "3    5\t(+ 10 (* #garlic #ginger)) 13",
        file_type = "generic")
    ok(cmp(unattr(gf), list(
        data.frame(
            col = as.integer(3),
            colm = as.integer(5),
            colt = I(list(
                quote(10 + (potato - 12)),
                quote(10 + log(cabbage)),
                quote(10 + garlic * ginger)
                )),
            coal = as.integer(13)))), "Multiple formulae")

    # Blank preamble lines get preserved
    test_loopback(
        ver_string,
        "a\t45",
        "; ",
        "[component]",
        "fish\tbattered")

    # Can have multiple lines with the same key
    test_loopback(
        ver_string,
        "a\t45",
        "a\t46",
        "a\t47")

    # Can have empty initial components
    test_loopback(
        ver_string,
        "[component]",
        "a\t46",
        "[component]",
        "a\t47")

    # Can have comments at the end of lines too
    test_loopback(
        ver_string,
        "; This is a preamble comment",
        "[component]",
        "a\t46\t\t; This is a comment at the end of a line",
        "a\t46\t47\t48\t49\t\t; This is a comment at the end of multiple values",
        "a\t; This is a comment at the end of an empty line")

    # Can read comments at the end of a file
    gf <- read.gadget.string(
        ver_string,
        "a\t99",
        "; Preamble for data",
        "; -- data --",
        "; col\tcolm\tcolt\tcoal",
        "3\t5\t9\t3",
        "7\t5\t33\t3",
        "3\t2\t9\t4",
        "[final]",
        "; preamble for line",
        "moo\tyes",
        "; postamble for entire file",
        "; The only way you can get one",
        file_type = "generic")
    ok(cmp(unattr(gf), list(
        list(a = 99),
        structure(
            data.frame(col = as.integer(c(3,7,3)), colm = as.integer(c(5,5,2)), colt = as.integer(c(9,33,9)), coal = as.integer(c(3,3,4))),
            preamble = list("Preamble for data")),
        final = structure(
            list(moo = structure('yes', preamble = list("preamble for line"))),
            postamble = list("postamble for entire file", "The only way you can get one"))
        )), "File postamble")
    test_loopback(
        ver_string,
        "a\t99",
        "; Preamble for data",
        "; -- data --",
        "; col\tcolm\tcolt\tcoal",
        "3\t5\t9\t3",
        "7\t5\t33\t3",
        "3\t2\t9\t4",
        "[final]",
        "; preamble for line",
        "moo\tyes",
        "; postamble for entire file",
        "; The only way you can get one")
})

ok_group("Bare component labels", {
    gf <- read.gadget.string(
        ver_string,
        "farmer\tgiles",
        "cows",
        "fresian\tdaisy",
        "highland\tbessie",
        "pigs",
        "oldspot\tgeorge",
        "pigs\thenry\tfreddie",
        file_type = "generic")
    ok(cmp(unattr(gf), list(list(
        farmer = "giles",
        cows = c(1)[c()],
        fresian = "daisy",
        highland = "bessie",
        pigs = c(1)[c()],
        oldspot = "george",
        pigs = c("henry", "freddie")
        ))), "By default, lines are just extra key/value fields")

    gf <- read.gadget.string(
        ver_string,
        "farmer\tgiles",
        "cows",
        "fresian\tdaisy",
        "highland\tbessie",
        "pigs",
        "oldspot\tgeorge",
        "pigs\thenry\tfreddie",
        file_type = "area")  # i.e. one with bare_component on
    ok(cmp(unattr(gf), list(
        list(farmer = "giles"),
        cows = list(fresian = "daisy", highland = "bessie"),
        pigs = list(oldspot = "george", pigs = c("henry", "freddie"))
        )), "Bare_component turns these into items")

    test_loopback(
        ver_string,
        "farmer\tgiles",
        "cows",
        "fresian\tdaisy",
        "highland\tbessie",
        "pigs",
        "oldspot\tgeorge",
        "pigs\thenry\tfreddie",
        file_type = "area")  # i.e. one with bare_component on
})

ok_group("Implicit component labels", {
    gf <- read.gadget.string(
        ver_string,
        "farmer\tgiles",
        "cows\t2",
        "fresian\tdaisy",
        "highland\tbessie",
        "pigs\t4",
        "oldspot\tgeorge",
        "gloucester\thenry\tfreddie",
        file_type = "generic")
    ok(cmp(unattr(gf), list(list(
        farmer = "giles",
        cows = 2,
        fresian = "daisy",
        highland = "bessie",
        pigs = 4,
        oldspot = "george",
        gloucester = c("henry", "freddie")
        ))), "By default, lines are just extra key/value fields")

    gf <- read.gadget.string(
        ver_string,
        "farmer\tgiles",
        "doesgrow\t2",
        "fresian\tdaisy",
        "highland\tbessie",
        "doeseat\t4",
        "oldspot\tgeorge",
        "gloucester\thenry\tfreddie",
        file_type = "stock")
    ok(cmp(unattr(gf), list(
        list(farmer = "giles"),
        doesgrow = list(doesgrow = 2, fresian = "daisy", highland = "bessie"),
        doeseat = list(doeseat = 4, oldspot = "george", gloucester = c("henry", "freddie"))
        )), "Turn on implicit components, and they get divided")

    test_loopback(
        ver_string,
        "farmer\tgiles",
        "doesgrow\t2",
        "fresian\tdaisy",
        "highland\tbessie",
        "doeseat\t4",
        "oldspot\tgeorge",
        "gloucester\thenry\tfreddie",
        file_type = "stock")
})

ok_group("Writing to mainfile", {
    dir <- tempfile()

    write.gadget.file(gadgetfile("wobble",
        components = list(list(cabbage = "definitely")),
        file_type = "area"), dir)
    ok(cmp(dir_list(dir), list(
        main = c(
            ver_string,
            "timefile\t",
            "areafile\twobble",
            "printfiles\t; Required comment",
            "[stock]",
            "[tagging]",
            "[otherfood]",
            "[fleet]",
            "[likelihood]",
        NULL),
        wobble = c(
            ver_string,
            "cabbage\tdefinitely",
        NULL)
    )), "Added area file to mainfile")

    write.gadget.file(gadgetfile("wubble",
        components = list(list(cabbage = "nah")),
        file_type = "area"), dir)
    ok(cmp(dir_list(dir), list(
        main = c(
            ver_string,
            "timefile\t",
            "areafile\twubble",
            "printfiles\t; Required comment",
            "[stock]",
            "[tagging]",
            "[otherfood]",
            "[fleet]",
            "[likelihood]",
        NULL),
        wobble = c(
            ver_string,
            "cabbage\tdefinitely",
        NULL),
        wubble = c(
            ver_string,
            "cabbage\tnah",
        NULL)
    )), "Extra area file replaces old")

    write.gadget.file(gadgetfile("likelihood/bubble",
        components = list(list(cabbage = "twice")),
        file_type = "likelihood"), dir)
    write.gadget.file(gadgetfile("likelihood/bobble",
        components = list(list(cabbage = "thrice")),
        file_type = "likelihood"), dir)
    ok(cmp(dir_list(dir), list(
        "likelihood/bobble" = c(
            ver_string,
            "cabbage\tthrice",
        NULL),
        "likelihood/bubble" = c(
            ver_string,
            "cabbage\ttwice",
        NULL),
        main = c(
            ver_string,
            "timefile\t",
            "areafile\twubble",
            "printfiles\t; Required comment",
            "[stock]",
            "[tagging]",
            "[otherfood]",
            "[fleet]",
            "[likelihood]",
            "likelihoodfiles\tlikelihood/bubble\tlikelihood/bobble",
        NULL),
        wobble = c(
            ver_string,
            "cabbage\tdefinitely",
        NULL),
        wubble = c(
            ver_string,
            "cabbage\tnah",
        NULL)
    )), "Can add multiple likelihood files")
})

ok_group("Can read fleet files successfully", {
    path <- tempdir()

    write.gadget.file(gadgetfile("Data/cod.fleet.data", components = list(comp = list(a=1))), path)
    write.gadget.file(gadgetfile("Data/cod.survey.data", components = list(comp = list(b=2))), path)

    test_loopback(
        ver_string,
        "[fleetcomponent]",
        "totalfleet\tcomm",
        "livesonareas\t1",
        "multiplicative\t1",
        "suitability",
        "codimm\tfunction\texponential\t#acomm\t(* 0.01 #bcomm)\t0\t1",
        "codmat\tfunction\texponential\t#acomm\t(* 0.01 #bcomm)\t0\t1",
        "amount\tData/cod.fleet.data",
        dir = path,
        file_type = "fleet")

    gf <- read.gadget.string(
        ver_string,
        "[fleetcomponent]",
        "totalfleet\tcomm",
        "livesonareas\t1",
        "multiplicative\t1",
        "suitability",
        "codimm\tfunction exponential    #acomm (* 0.01 #bcomm)  0 1",  # NB: We don't use tabs here
        "codmat\tfunction exponential    #acomm (* 0.01 #bcomm)  0 1",
        "amount\tData/cod.fleet.data",
        "[fleetcomponent]",
        "totalfleet\tsurvey",
        "livesonareas\t1",
        "multiplicative\t1",
        "suitability",
        "codimm\tfunction exponential    #acomm (* 0.05 #bcomm)  0 1",
        "codmat\tfunction exponential    #acomm (* 0.05 #bcomm)  0 1",
        "amount\tData/cod.survey.data",
        dir = path,
        file_type = "fleet")
    ok(cmp(unattr(gf), list(
        fleetcomponent = list(
            totalfleet = "comm",
            livesonareas = 1,
            multiplicative = 1,
            suitability = list(
                codimm = list("function", "exponential", "#acomm", quote(0.01 * bcomm), "0", "1"),
                codmat = list("function", "exponential", "#acomm", quote(0.01 * bcomm), "0", "1")
            ),
            amount = gadgetfile("Data/cod.fleet.data", components = list(comp = list(a=1)))
        ),
        fleetcomponent = list(
            totalfleet = "survey",
            livesonareas = 1,
            multiplicative = 1,
            suitability = list(
                codimm = list("function", "exponential", "#acomm", quote(0.05 * bcomm), "0", "1"),
                codmat = list("function", "exponential", "#acomm", quote(0.05 * bcomm), "0", "1")
            ),
            amount = gadgetfile("Data/cod.survey.data", components = list(comp = list(b=2)))
        )
    )), "Fleet file with multiple components read")
})

ok_group("Can read nested files in one go", {
    dir <- tempfile()

    # NB: all.equal can tell the difference between names() == "" and names() == NULL,
    # even though there's no sematic difference. Label all components to avoid this.
    nested_files <- gadgetfile("wobble", components = list(comp = list(
        subfile = gadgetfile("sub/subfile", components = list(comp = list(potatoes = as.numeric(1:4)))),
        anotherfile = gadgetfile("sub/anotherfile", components = list(comp = list(potatoes = as.numeric(6:8))))
    )))
    write.gadget.file(nested_files, dir)
    ok(cmp(dir_list(dir), list(
        "sub/anotherfile" = c(
            ver_string,
            "[comp]",
            "potatoes\t6\t7\t8",
        NULL),
        "sub/subfile" = c(
            ver_string,
            "[comp]",
            "potatoes\t1\t2\t3\t4",
        NULL),
        wobble = c(
            ver_string,
            "[comp]",
            "subfile\tsub/subfile",
            "anotherfile\tsub/anotherfile",
        NULL)
    )), "Wrote out multiple gadget files in one go")

    ok(cmp(read.gadget.file(dir, "wobble"), nested_files), "Read all files back in again")
})

ok_group("Variant directories", {
    dir <- tempfile()
    variant_dir <- gadget.variant.dir(dir, variant_dir = 'similar')

    # Write base files
    write.gadget.file(gadgetfile("area.cabbage",
        components = list(list(cabbage = "nah")),
        file_type = "area"), dir)
    write.gadget.file(gadgetfile("likelihood/bubble",
        components = list(list(cabbage = "twice")),
        file_type = "likelihood"), dir)

    # Write extra file to variant dir
    write.gadget.file(gadgetfile("likelihood/bubble.variant",
        components = list(list(cabbage = "thrice")),
        file_type = "likelihood"), variant_dir)

    ok(cmp(dir_list(dir), list(
        "area.cabbage" = c(
            ver_string,
            "cabbage\tnah",
        NULL),
        "likelihood/bubble" = c(
            ver_string,
            "cabbage\ttwice",
        NULL),
        main = c(
            ver_string,
            "timefile\t",
            "areafile\tarea.cabbage",
            "printfiles\t; Required comment",
            "[stock]",
            "[tagging]",
            "[otherfood]",
            "[fleet]",
            "[likelihood]",
            "likelihoodfiles\tlikelihood/bubble",
        NULL),
        "similar/likelihood/bubble.variant" = c(
            ver_string,
            "cabbage\tthrice",
        NULL),
        "similar/main" = c(
            ver_string,
            "timefile\t",
            # NB: We've read in the exisiting file, then outputted the variant.
            "areafile\tarea.cabbage",
            "printfiles\t; Required comment",
            "[stock]",
            "[tagging]",
            "[otherfood]",
            "[fleet]",
            "[likelihood]",
            paste("likelihoodfiles",
                "likelihood/bubble",
                "similar/likelihood/bubble.variant",
                sep = "\t"),
        NULL)
    )), "Can add a likelihood file in a variant directory")

    bubble_variant <- read.gadget.file(dir, "similar/likelihood/bubble.variant")
    attr(bubble_variant, 'file_name') <- "likelihood/bubble.variant"
    ok(cmp(
        bubble_variant,
        read.gadget.file(variant_dir, "likelihood/bubble.variant")), "Don't have to include path when using variant_dir")
    ok(cmp(
        bubble_variant,
        read.gadget.file(variant_dir, "similar/likelihood/bubble.variant")), "Don't have to include path when using variant_dir")
    ok(cmp(
        read.gadget.file(dir, "area.cabbage"),
        read.gadget.file(variant_dir, "area.cabbage")), "Fall back to normal dir when using variant_dir")
    ok(cmp(
        read.gadget.file(dir, "area.cabbage"),
        read.gadget.file(variant_dir, "similar/area.cabbage")), "Fall back to normal dir when using variant_dir")
})

ok_group("split_gadgetfile_line", {
    split_gadgetfile_line <- Rgadget:::split_gadgetfile_line

    ok(cmp(split_gadgetfile_line(""), c("")), "Empty string raises no errors")

    ok(cmp(split_gadgetfile_line("a"), c("a")), "Single character works")

    ok(cmp(split_gadgetfile_line("a\tb\tc\t(d (\te) ) f"), c(
        "a",
        "b",
        "c",
        "(d ( e) )",
        "f",
        NULL)), "Tabs inside expression converted to spaces")
})

ok_group("Can read time variable files successfully", {
    path <- tempdir()

    test_loopback(
        ver_string,
        "annualgrowth\t",
        "data",
        "; year\tstep\tvalue",
        "1995\t1\t#grow1995",
        "1996\t1\t#grow1996",
        "1997\t1\t#grow1997",
        "1998\t1\t#grow1998",
        "1999\t1\t#grow1999",
        "2000\t1\t#grow2000",
        dir = path,
        file_type = "timevariable")

    gf <- read.gadget.string(
        ver_string,
        "annualgrowth",
        "data",
        "; year  step    value",
        "1995    1       #grow1995",
        "1996    1       #grow1996",
        "1997    1       #grow1997",
        "1998    1       #grow1998",
        "1999    1       #grow1999",
        "2000    1       #grow2000",
        dir = path,
        file_type = "timevariable")
    ok(cmp(unattr(gf), list(list(
        annualgrowth = as.numeric(),
        data = data.frame(
            year = 1995:2000,
            step = 1,
            value = paste0('#grow', 1995:2000),
            stringsAsFactors = TRUE)
    ))), "Time variable file read")
})

ok_group("Can read stock variable files successfully", {
    path <- tempdir()

    test_loopback(
        ver_string,
        "biomass\t",
        "codimm\t",
        "codmat\t",
        dir = path,
        file_type = "stockvariable")

    gf <- read.gadget.string(
        ver_string,
        "biomass\t1",
        "codimm",
        "codmat",
        dir = path,
        file_type = "stockvariable")
    ok(cmp(unattr(gf), list(list(
        biomass = as.integer(1),
        codimm = as.numeric(c()),
        codmat = as.numeric(c())))), "Stock variable file read")
})
