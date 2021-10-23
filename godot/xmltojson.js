var htmlfile = WSH.CreateObject('htmlfile'), JSON;
htmlfile.write('<meta http-equiv="x-ua-compatible" content="IE=9" />');
// NOTE: JSON doesn't stringify arrays properly
htmlfile.close(JSON = htmlfile.parentWindow.JSON);
shims();

var shell = WScript.CreateObject('WScript.Shell');
var file;
try {
    file = WScript.StdOut;
} catch (ex) {
    ex.message = outfile + '\n' + ex.message;
    throw ex;
}

var doc = new ActiveXObject('Msxml2.DOMDocument.6.0');
var filename = WScript.Arguments.length && WScript.Arguments(0);
if (!filename) {
    throw new Error('No filename argument');
}
doc.async = false;
var loaded = doc.load(filename);
if (!loaded || !doc.documentElement) {
    log(doc.parseError.errorCode);
    log(doc.parseError.url);
    log(doc.parseError.reason);
    log(doc.parseError.srcText);
    log(doc.parseError.line);
    throw new Error('DocumentElement is ' + doc.documentElement + ' loading ' + filename + ' ' + stringify(loaded));
}
file.Write(stringify(parseDomNode(doc.documentElement).value));


function parseDomNode(elem) {
    // these nodes can be too big.
    var BLACKLIST = ['DirectShow', 'MediaFoundation'];
    var NODE_TEXT = 3;
    var result = {
        name: elem.nodeName
    };
    var children = []
    var child = elem.firstChild;
    while (child) {
        if (child.nodeType != NODE_TEXT) {
            var cNode = parseDomNode(child);
            children.push(cNode);
        }
        child = child.nextSibling;
    }
    if (children.length) {
        result.children = children;
    } else {
        result.value = elem.text || elem.nodeValue;
    }
    var attrs = elem.attributes;
    if (attrs && attrs.length) {
        result.attrs = {};
        try {
            for (var i = 0; i < attrs.length; ++i) {
                result.attrs[attrs[i].name] = attrs[i].value;
            }
        } catch (ex) { log(ex.message); log(attrs); throw ex}
    }

    if (result.children && !result.attrs) {
        var children = result.children;
        result.value = {};
        for (var i = 0; i < children.length; ++i) {
            if (BLACKLIST.indexOf(children[i].name) > -1) {
                result.value[children[i].name] = '--skipped--'
            } else {
                result.value[children[i].name] = children[i].value;
            }
        }
        delete result.children;
    }
    return result;
}

var cscript;
function log(msg) {
    if (cscript === undefined) {
        var m = /\\(w|c)script\.exe$/i.exec(WScript.FullName);
        cscript = m && m[1] === 'c';
    }
    if (cscript) {
        WScript.StdErr.Write(msg + '\n');
    }
}

function stringify(value, d) {
    d = d || 0;
    var t1 = Array(d + 1).join(' ');
    var t2 = t1 + ' ';
    if (value && typeof value === 'object') {
        var result = [];
        var s = '{', e = '}';
        if (value instanceof Array) {
            s = '[';
            e = ']';
            result = value.map(function(v) { return stringify(v, d + 1);});
        } else {
            for (var k in value) {
                result.push(stringify(k) + ':' + stringify(value[k], d + 1));
            }
        }
        return s + '\n' + t2 + result.join(',\n' + t2) + '\n' + t1 + e;
    } else {
        return JSON.stringify(value);
    }
}

function shims() {
    Array.prototype.indexOf = Array.prototype.indexOf || function(item, start) {
        var length = this.length
        start = start !== undefined ? start : 0
        for (var i = start; i < length; i++) {
            if (this[i] === item) return i
        }
        return -1
    }
    Array.prototype.map = Array.prototype.map || function(cb) {
        var  r = [];
        for (var i = 0; i < this.length; ++i) {
            r.push(cb(this[i]));
        }
        return r;
    }
}