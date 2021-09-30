xquery version "3.1";
module namespace alpheios = "https://betamasaheft.eu/alpehios";
declare namespace t = "http://www.tei-c.org/ns/1.0";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "xml";
declare option output:indent "yes";
declare variable $alpheios:traces := doc('/db/apps/alpheiosannotations/tracesValues.xml');


declare function alpheios:do-add($commits, $contents-url as xs:string?) {
    let $committerEmail := $commits?1?pusher?email
    return
        
        for $modified in $commits?1?added?*
        let $file-path := concat($contents-url, $modified)
        let $gitToken := environment-variable('GITTOKEN')
        (:environment-variable('GIT_TOKEN'):)
        let $req :=
        <http:request
        http-version="1.1"
            href="{xs:anyURI($file-path)}"
            method="GET">
            <http:header
                name="Authorization"
                value="{('token ' || $gitToken)}"/>
        </http:request>
       
        let $file := http:send-request($req)[2]
        let $thispayload := util:base64-decode($file)
        let $JSON := parse-json($thispayload)
        let $file-data := $JSON?content
        let $file-name := $JSON?name
        let $collection := xs:anyURI($data-collection)
        let $resource-path := substring-before($modified, $file-name)
        let $collection-uri := '/db/apps/tracesData'
        return
            try {
                ( let $TEI := alpheios:toFS($alpheiosjsonexport)
               return <response
                        status="okay">
                        <message>
                            {xmldb:store($collection-uri, xmldb:encode-uri($file-name), xs:base64Binary($TEI)),
                       sm:chmod(xs:anyURI(concat($collection-uri, '/', $file-name)), 'rwxrwxr-x'),
                                sm:chgrp(xs:anyURI(concat($collection-uri, '/', $file-name)), 'Cataloguers')}
                        </message>
                    </response>)
            } catch * {
            (
                <response
                    status="fail">
                    <message>Failed to add resource: {concat($err:code, ": ", $err:description)}
                    </message>
                </response>)
            }
};

declare function alpheios:parse-request($json-data) {
let $cturl := $repository?contents_url
let $contents-url := substring-before($cturl, '{')
return
        try {
            if ($json-data?ref = "refs/heads/master") then
                if (exists($json-data?commits)) then
                    let $commits := $json-data?commits
                    return
                        alpheios:do-add($commits, $contents-url)
                        
                else
                    (<response
                        status="fail"><message>This is a GitHub request, however there were no commits.</message></response>
                        ,
                        gitsync:failedCommitMessage('', $data-collection, 'This is a GitHub request, however there were no commits.')
                        )
            else
                (<response
                    status="fail"><message>Not from the master branch.</message></response>,
                        gitsync:mergeCommitMessage('', $data-collection, 'Not from the master branch.', $json-data?ref)
                        )
                        
        } catch * {
            (<response
                status="fail">
                <message>{concat($err:code, ": ", $err:description)}</message>
            </response>,
                        gitsync:failedCommitMessage('', $data-collection, concat($err:code, ": ", $err:description))
                        )
        }
};


declare function alpheios:toFS($alpheiosjsonexport){
let $file := $alpheiosjsonexport
(:let $parsed := parse-json($file):)
let $metadata := $file?origin?docSource?metadata?properties?*
let $originToks := $file?origin?alignedText?segments?*?tokens?*
let $targets := $file?targets
let $alignments := $file?alignmentGroups?*
let $annotations := $file?annotations
return
    
    <TEI
        xmlns="https://www.tei-c.org/ns/1.0"
        xml:id="{$file?origin?docSource?textId}">
        <teiHeader>
            <fileDesc>
                <titleStmt>
                    <title>{$metadata[?property = "title"]?value}</title>
                </titleStmt>
                <publicationStmt>
                    <ab>Annotations made with Alpheios Alignment tool</ab>
                    <date
                        type="created">{$file?createdDT}</date>
                    <date
                        type="updated">{$file?updatedDT}</date>
                </publicationStmt>
                <sourceDesc>
                    <ab/>
                </sourceDesc>
            </fileDesc>
        </teiHeader>
        <text>
            <body>
                {
                    for $group in $alignments
                    let $targetId := $group?actions?targetId
                    let $targetToks := $targets($targetId)?alignedText?segments?*?tokens?*
                    let $origin := $group?actions?origin?*
                    let $originString := for $o in $origin
                    return
                        $originToks[?idWord = $o]?word
                    let $target := $group?actions?target?*
                    let $targetString := for $t in $target
                    return
                        $targetToks[?idWord = $t]?word
                    
                    let $targetannotations := for $t in $target
                    return
                        $annotations($t)
                    
                    return
                        
                        <fs
                            type="graphunit"
                            xml:id="W{$group?id}">
                            <f
                                name="fidäl">{$originString}</f>
                            <f
                                name="translit">{string-join($targetString, '-')}</f>
                            {
                            if (count($targetannotations) ge 1) then
                                    <f
                                        name="analysis">
                                        <fs
                                            type="tokens">
                                            {
                                            for $t in $target
                                                let $annT := $annotations($t)?*
                                                return
                                                    <f
                                                        name="lit"
                                                        fVal="{$targetToks[?idWord = $t]?word}"><fs
                                                            type="morpho">
                                                            {
                                                            if ($annT?type = 'MORPHOLOGY') then
                                                                    for $a in $annT[?type = 'MORPHOLOGY']
                                                                    for $anno in tokenize(string($a?text), ';')
                                                                    let $fname := $traces//*:val[.='anno']/parent::name/@name
                                                                return
                                                                    <f>{$fname}{$anno}</f>
                                                            else
                                                                ()
                                                        }
                                                        {
                                                            if ($annT?type = 'LEMMAID') then
                                                                for $a in $annT[?type = 'LEMMAID']
                                                                return
                                                                    <f
                                                                        name="lex">{substring-after($a?text, 'https://betamasaheft.eu/Dillmann/lemma/')}--{$originString}</f>
                                                            else
                                                                ()
                                                        }
                                                    </fs></f>
                                        }
                                    </fs></f>
                            else
                                ()
                        }
                    </fs>
            }
        
        
        </body>
    </text>
</TEI>};
