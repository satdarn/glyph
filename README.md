# GLYPH

## The idea is a toy browser... nothing fancy

## UNDER CONSTRUCTION... THINGS TO COME (Fingers crossed)

- A "Spec" HTML Tokenizer
- A "Spec" HTML Parser
- A Dom render for unix/linux systems (idk bout macOs)
- Networking (Probably by libcurl)

## DO I THINK THIS PROJECT WILL DIE

Yes

## IS THAT STOPING ME AT FUCKING ALL

no, not really

## Language i plan on using is zig

cause i fucking feel like it rn 

## Instilation B)

``` bash
git clone https://github.com/satdarn/glyph.git
cd glyph
zig build
mv zig-out/bin/glyph /usr/local/bin/glyph // (OR WHERE EVER YOUR PATH AT)
glyph --help
```

## TODO:

- [ ] Tokenizer
- [ ] Parser 
- [ ] Render

## GOALS:

currently i would like to tokenize and parse into a dom the following 

``` HTML
<!DOCTYPE html>
<html>
    <head>
        <title>Mr Beans Poopy site</title>
    </head>
    <body>
        <h1>
            IM A MOTHERFUCKING WEBSITE
        </h1>
        <h2>
            WHAT DO YOU MEAN HTMLS NOT A PROGRAMING LANGUAGE
        </h2>
    </body>
</html>


```
