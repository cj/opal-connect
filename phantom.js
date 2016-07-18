var webPage = require('webpage');
var page    = webPage.create();
var system  = require('system');
var args    = system.args.slice(1);

page.settings.resourceTimeout = 25000; // 55 seconds

page.onResourceTimeout = function(e) {
  console.log(e.errorCode);   // it'll probably be 408 
  console.log(e.errorString); // it'll probably be 'Network timeout on resource'
  console.log(e.url);         // the url whose request timed out
  phantom_exit(0);
};

page.onConsoleMessage = function(msg) {
  system.stderr.writeLine(msg);
};

/*
 * Exit phantom instance "safely" see - https://github.com/ariya/phantomjs/issues/12697
 * https://github.com/nobuoka/gulp-qunit/commit/d242aff9b79de7543d956e294b2ee36eda4bac6c
 */
function phantom_exit(code) {
  page.close();
  setTimeout(function () { phantom.exit(code); }, 0);
}

page.open(args[0], 'GET', function(status) {
  phantom_exit(0);
});
