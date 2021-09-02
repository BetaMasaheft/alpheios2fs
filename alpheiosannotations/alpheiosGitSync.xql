xquery version "3.1";
import module namespace alpheios = "https://betamasaheft.eu/alpehios" at "xmldb:exist:///db/apps/alpheiosannotations/alpheios2TEIfs.xqm";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace crypto = "http://expath.org/ns/crypto";
import module namespace config = "https://www.betamasaheft.uni-hamburg.de/BetMas/config" at "xmldb:exist:///db/apps/BetMas/modules/config.xqm";
declare option exist:serialize "method=xml media-type=text/xml indent=yes";





let $post-data := request:get-data()

return
    if (not(empty($post-data))) then
        let $payload := util:base64-decode($post-data)
        let $json-data := parse-json($payload)
       
        return
            try {
                
                if (matches(request:get-header('User-Agent'), '^GitHub-Hookshot/')) then
                    if (request:get-header('X-GitHub-Event') = 'push') then
                        let $signiture := request:get-header('X-Hub-Signature')
                        let $expected-result := <expected-result>{request:get-header('X-Hub-Signature')}</expected-result>
                        let $private-key := environment-variable('GIT_SECRETalpheios')
                        let $actual-result :=
                        <actual-result>
                            {concat('sha1=', crypto:hmac($payload, $private-key, "HMAC-SHA-1", "hex"))}
                        </actual-result>
                        let $condition := normalize-space($expected-result/text()) = normalize-space($actual-result/text())
                        return
                            if ($condition) then
                                alpheios:parse-request($json-data)
                            else
                                <response
                                    status="fail"><message>Invalid secret.</message></response>
                    else
                        <response
                            status="fail"><message>Invalid trigger.</message></response>
                else
                    <response
                        status="fail"><message>This is not a GitHub request.</message></response>
            } catch * {
                <response
                    status="fail">
                    <message>Unacceptable headers {concat($err:code, ": ", $err:description)}</message>
                </response>
            }
    else
        <response
            status="fail">
            <message>No post data recieved</message>
        </response>