<cfsetting requestTimeout="600" showDebugOutput="false">
<cfscript>
// Top-level `var` declarations are not supported on ACF; wrap the runner in a
// named function and call it. Lucee/ACF/BoxLang all accept this form.
function _runAshidSpecs() {
	var specsDir = expandPath("/ashid/tests/specs/");
	// ACF 2016 rejects named args on directoryList(). Positional form is portable
	// across all four engines: (path, recurse, listInfo, filter).
	var specFiles = directoryList(specsDir, false, "path", "*.cfc");
	arraySort(specFiles, "textnocase");

	var allBundles = [];
	var totalPass = 0;
	var totalFail = 0;
	var totalElapsed = 0;

	for (var specPath in specFiles) {
		var fileName = listLast(replace(specPath, "\", "/", "all"), "/");
		var componentName = "tests.specs." & listFirst(fileName, ".");
		var spec = createObject("component", componentName);

		var t0 = getTickCount();
		var results = [];
		var bundleError = "";
		try {
			results = spec.run();
		} catch (any e) {
			bundleError = (structKeyExists(e, "message") ? e.message : toString(e));
		}
		var elapsed = getTickCount() - t0;
		totalElapsed += elapsed;

		var pass = 0;
		var fail = 0;
		for (var r in results) {
			if (r.status eq "pass") pass++;
			else fail++;
		}
		totalPass += pass;
		totalFail += fail;

		arrayAppend(allBundles, [
			"name":    componentName,
			"results": results,
			"pass":    pass,
			"fail":    fail,
			"elapsed": elapsed,
			"error":   bundleError
		]);
	}

	return [
		"allBundles":   allBundles,
		"totalPass":    totalPass,
		"totalFail":    totalFail,
		"totalElapsed": totalElapsed
	];
}

runResult    = _runAshidSpecs();
allBundles   = runResult.allBundles;
totalPass    = runResult.totalPass;
totalFail    = runResult.totalFail;
totalElapsed = runResult.totalElapsed;

isText = (structKeyExists(url, "format") && url.format eq "text");
</cfscript>
<cfif isText>
<cfoutput>[#totalPass# passed] [#totalFail# failed] [#arrayLen(allBundles)# bundles] [#totalElapsed# ms]
<cfloop array="#allBundles#" index="b">
#b.name# (#b.pass# pass / #b.fail# fail / #b.elapsed# ms)<cfif len(b.error)> -- BUNDLE ERROR: #b.error#</cfif>
<cfloop array="#b.results#" index="r"><cfif r.status eq "fail">  FAIL: #r.name# -- #r.message#
</cfif></cfloop></cfloop></cfoutput>
<cfelse>
<!doctype html>
<html><head><meta charset="utf-8"><title>ashid tests</title>
<style>
body { font-family: -apple-system, Segoe UI, sans-serif; max-width: 1000px; margin: 2em auto; padding: 0 1em; color: #222; }
h1 { font-size: 1.4em; }
.summary { padding: .8em; background: #f5f5f5; border-radius: 4px; margin-bottom: 1.5em; font-size: 1.1em; }
.summary.pass { background: #e6f7e6; border-left: 4px solid #2a8a2a; }
.summary.fail { background: #fde8e8; border-left: 4px solid #c0392b; }
.bundle { margin-bottom: 1.5em; }
.bundle h2 { font-size: 1.05em; margin-bottom: .3em; color: #333; }
.bundle .bundle-stats { color: #666; font-size: .85em; margin-bottom: .5em; }
.bundle .bundle-error { color: #c0392b; font-weight: bold; padding: .5em; background: #fde8e8; }
ul.specs { list-style: none; padding-left: 0; }
ul.specs li { padding: .25em .5em; margin-bottom: .15em; border-radius: 3px; font-family: SFMono-Regular, Consolas, monospace; font-size: .9em; }
ul.specs li.pass { color: #2a8a2a; }
ul.specs li.fail { color: #c0392b; background: #fde8e8; }
ul.specs li.fail .msg { display: block; padding-left: 1.5em; color: #8a2a2a; font-size: .85em; }
</style>
</head><body>
<cfoutput>
<h1>ashid test runner</h1>
<div class="summary #(totalFail eq 0 ? 'pass' : 'fail')#">
	<strong>#totalPass#</strong> passed,
	<strong>#totalFail#</strong> failed
	&mdash; #arrayLen(allBundles)# bundles, #totalElapsed# ms
	on #server.coldfusion.productname# #server.coldfusion.productversion#
</div>
<cfloop array="#allBundles#" index="b">
	<div class="bundle">
		<h2>#b.name#</h2>
		<div class="bundle-stats">#b.pass# pass / #b.fail# fail / #b.elapsed# ms</div>
		<cfif len(b.error)>
			<div class="bundle-error">BUNDLE ERROR: #encodeForHtml(b.error)#</div>
		</cfif>
		<ul class="specs">
			<cfloop array="#b.results#" index="r">
				<li class="#r.status#">
					<cfif r.status eq "pass">&##10004; #encodeForHtml(r.name)#<cfelse>&##10008; #encodeForHtml(r.name)# <span class="msg">#encodeForHtml(r.message)#</span></cfif>
				</li>
			</cfloop>
		</ul>
	</div>
</cfloop>
<p style="color:##888;font-size:.85em;">Plain text: <a href="?format=text">?format=text</a></p>
</cfoutput>
</body></html>
</cfif>
