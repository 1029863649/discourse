 //@license magnet:?xt=urn:btih:cf05388f2679ee054f2beb29a391d25f4e673ac3&dn=gpl-2.0.txt GPL-v2-or-Later
ace.define("ace/snippets",["require","exports","module","ace/lib/oop","ace/lib/event_emitter","ace/lib/lang","ace/range","ace/anchor","ace/keyboard/hash_handler","ace/tokenizer","ace/lib/dom","ace/editor"],function(e,t,n){"use strict";var r=e("./lib/oop"),i=e("./lib/event_emitter").EventEmitter,s=e("./lib/lang"),o=e("./range").Range,u=e("./anchor").Anchor,a=e("./keyboard/hash_handler").HashHandler,f=e("./tokenizer").Tokenizer,l=o.comparePoints,c=function(){this.snippetMap={},this.snippetNameMap={}};(function(){r.implement(this,i),this.getTokenizer=function(){function e(e,t,n){return e=e.substr(1),/^\d+$/.test(e)&&!n.inFormatString?[{tabstopId:parseInt(e,10)}]:[{text:e}]}function t(e){return"(?:[^\\\\"+e+"]|\\\\.)"}return c.$tokenizer=new f({start:[{regex:/:/,onMatch:function(e,t,n){return n.length&&n[0].expectIf?(n[0].expectIf=!1,n[0].elseBranch=n[0],[n[0]]):":"}},{regex:/\\./,onMatch:function(e,t,n){var r=e[1];return r=="}"&&n.length?e=r:"`$\\".indexOf(r)!=-1?e=r:n.inFormatString&&(r=="n"?e="\n":r=="t"?e="\n":"ulULE".indexOf(r)!=-1&&(e={changeCase:r,local:r>"a"})),[e]}},{regex:/}/,onMatch:function(e,t,n){return[n.length?n.shift():e]}},{regex:/\$(?:\d+|\w+)/,onMatch:e},{regex:/\$\{[\dA-Z_a-z]+/,onMatch:function(t,n,r){var i=e(t.substr(1),n,r);return r.unshift(i[0]),i},next:"snippetVar"},{regex:/\n/,token:"newline",merge:!1}],snippetVar:[{regex:"\\|"+t("\\|")+"*\\|",onMatch:function(e,t,n){n[0].choices=e.slice(1,-1).split(",")},next:"start"},{regex:"/("+t("/")+"+)/(?:("+t("/")+"*)/)(\\w*):?",onMatch:function(e,t,n){var r=n[0];return r.fmtString=e,e=this.splitRegex.exec(e),r.guard=e[1],r.fmt=e[2],r.flag=e[3],""},next:"start"},{regex:"`"+t("`")+"*`",onMatch:function(e,t,n){return n[0].code=e.splice(1,-1),""},next:"start"},{regex:"\\?",onMatch:function(e,t,n){n[0]&&(n[0].expectIf=!0)},next:"start"},{regex:"([^:}\\\\]|\\\\.)*:?",token:"",next:"start"}],formatString:[{regex:"/("+t("/")+"+)/",token:"regex"},{regex:"",onMatch:function(e,t,n){n.inFormatString=!0},next:"start"}]}),c.prototype.getTokenizer=function(){return c.$tokenizer},c.$tokenizer},this.tokenizeTmSnippet=function(e,t){return this.getTokenizer().getLineTokens(e,t).tokens.map(function(e){return e.value||e})},this.$getDefaultValue=function(e,t){if(/^[A-Z]\d+$/.test(t)){var n=t.substr(1);return(this.variables[t[0]+"__"]||{})[n]}if(/^\d+$/.test(t))return(this.variables.__||{})[t];t=t.replace(/^TM_/,"");if(!e)return;var r=e.session;switch(t){case"CURRENT_WORD":var i=r.getWordRange();case"SELECTION":case"SELECTED_TEXT":return r.getTextRange(i);case"CURRENT_LINE":return r.getLine(e.getCursorPosition().row);case"PREV_LINE":return r.getLine(e.getCursorPosition().row-1);case"LINE_INDEX":return e.getCursorPosition().column;case"LINE_NUMBER":return e.getCursorPosition().row+1;case"SOFT_TABS":return r.getUseSoftTabs()?"YES":"NO";case"TAB_SIZE":return r.getTabSize();case"FILENAME":case"FILEPATH":return"";case"FULLNAME":return"Ace"}},this.variables={},this.getVariableValue=function(e,t){return this.variables.hasOwnProperty(t)?this.variables[t](e,t)||"":this.$getDefaultValue(e,t)||""},this.tmStrFormat=function(e,t,n){var r=t.flag||"",i=t.guard;i=new RegExp(i,r.replace(/[^gi]/,""));var s=this.tokenizeTmSnippet(t.fmt,"formatString"),o=this,u=e.replace(i,function(){o.variables.__=arguments;var e=o.resolveVariables(s,n),t="E";for(var r=0;r<e.length;r++){var i=e[r];if(typeof i=="object"){e[r]="";if(i.changeCase&&i.local){var u=e[r+1];u&&typeof u=="string"&&(i.changeCase=="u"?e[r]=u[0].toUpperCase():e[r]=u[0].toLowerCase(),e[r+1]=u.substr(1))}else i.changeCase&&(t=i.changeCase)}else t=="U"?e[r]=i.toUpperCase():t=="L"&&(e[r]=i.toLowerCase())}return e.join("")});return this.variables.__=null,u},this.resolveVariables=function(e,t){function o(t){var n=e.indexOf(t,r+1);n!=-1&&(r=n)}var n=[];for(var r=0;r<e.length;r++){var i=e[r];if(typeof i=="string")n.push(i);else{if(typeof i!="object")continue;if(i.skip)o(i);else{if(i.processed<r)continue;if(i.text){var s=this.getVariableValue(t,i.text);s&&i.fmtString&&(s=this.tmStrFormat(s,i)),i.processed=r,i.expectIf==null?s&&(n.push(s),o(i)):s?i.skip=i.elseBranch:o(i)}else i.tabstopId!=null?n.push(i):i.changeCase!=null&&n.push(i)}}}return n},this.insertSnippetForSelection=function(e,t){function f(e){var t=[];for(var n=0;n<e.length;n++){var r=e[n];if(typeof r=="object"){if(a[r.tabstopId])continue;var i=e.lastIndexOf(r,n-1);r=t[i]||{tabstopId:r.tabstopId}}t[n]=r}return t}var n=e.getCursorPosition(),r=e.session.getLine(n.row),i=e.session.getTabString(),s=r.match(/^\s*/)[0];n.column<s.length&&(s=s.slice(0,n.column));var o=this.tokenizeTmSnippet(t);o=this.resolveVariables(o,e),o=o.map(function(e){return e=="\n"?e+s:typeof e=="string"?e.replace(/\t/g,i):e});var u=[];o.forEach(function(e,t){if(typeof e!="object")return;var n=e.tabstopId,r=u[n];r||(r=u[n]=[],r.index=n,r.value="");if(r.indexOf(e)!==-1)return;r.push(e);var i=o.indexOf(e,t+1);if(i===-1)return;var s=o.slice(t+1,i),a=s.some(function(e){return typeof e=="object"});a&&!r.value?r.value=s:s.length&&(!r.value||typeof r.value!="string")&&(r.value=s.join(""))}),u.forEach(function(e){e.length=0});var a={};for(var l=0;l<o.length;l++){var c=o[l];if(typeof c!="object")continue;var p=c.tabstopId,d=o.indexOf(c,l+1);if(a[p]){a[p]===c&&(a[p]=null);continue}var v=u[p],m=typeof v.value=="string"?[v.value]:f(v.value);m.unshift(l+1,Math.max(0,d-l)),m.push(c),a[p]=c,o.splice.apply(o,m),v.indexOf(c)===-1&&v.push(c)}var g=0,y=0,b="";o.forEach(function(e){typeof e=="string"?(e[0]==="\n"?(y=e.length-1,g++):y+=e.length,b+=e):e.start?e.end={row:g,column:y}:e.start={row:g,column:y}});var w=e.getSelectionRange(),E=e.session.replace(w,b),S=new h(e),x=e.inVirtualSelectionMode&&e.selection.index;S.addTabstops(u,w.start,E,x)},this.insertSnippet=function(e,t){var n=this;if(e.inVirtualSelectionMode)return n.insertSnippetForSelection(e,t);e.forEachSelection(function(){n.insertSnippetForSelection(e,t)},null,{keepOrder:!0}),e.tabstopManager&&e.tabstopManager.tabNext()},this.$getScope=function(e){var t=e.session.$mode.$id||"";t=t.split("/").pop();if(t==="html"||t==="php"){t==="php"&&!e.session.$mode.inlinePhp&&(t="html");var n=e.getCursorPosition(),r=e.session.getState(n.row);typeof r=="object"&&(r=r[0]),r.substring&&(r.substring(0,3)=="js-"?t="javascript":r.substring(0,4)=="css-"?t="css":r.substring(0,4)=="php-"&&(t="php"))}return t},this.getActiveScopes=function(e){var t=this.$getScope(e),n=[t],r=this.snippetMap;return r[t]&&r[t].includeScopes&&n.push.apply(n,r[t].includeScopes),n.push("_"),n},this.expandWithTab=function(e,t){var n=this,r=e.forEachSelection(function(){return n.expandSnippetForSelection(e,t)},null,{keepOrder:!0});return r&&e.tabstopManager&&e.tabstopManager.tabNext(),r},this.expandSnippetForSelection=function(e,t){var n=e.getCursorPosition(),r=e.session.getLine(n.row),i=r.substring(0,n.column),s=r.substr(n.column),o=this.snippetMap,u;return this.getActiveScopes(e).some(function(e){var t=o[e];return t&&(u=this.findMatchingSnippet(t,i,s)),!!u},this),u?t&&t.dryRun?!0:(e.session.doc.removeInLine(n.row,n.column-u.replaceBefore.length,n.column+u.replaceAfter.length),this.variables.M__=u.matchBefore,this.variables.T__=u.matchAfter,this.insertSnippetForSelection(e,u.content),this.variables.M__=this.variables.T__=null,!0):!1},this.findMatchingSnippet=function(e,t,n){for(var r=e.length;r--;){var i=e[r];if(i.startRe&&!i.startRe.test(t))continue;if(i.endRe&&!i.endRe.test(n))continue;if(!i.startRe&&!i.endRe)continue;return i.matchBefore=i.startRe?i.startRe.exec(t):[""],i.matchAfter=i.endRe?i.endRe.exec(n):[""],i.replaceBefore=i.triggerRe?i.triggerRe.exec(t)[0]:"",i.replaceAfter=i.endTriggerRe?i.endTriggerRe.exec(n)[0]:"",i}},this.snippetMap={},this.snippetNameMap={},this.register=function(e,t){function o(e){return e&&!/^\^?\(.*\)\$?$|^\\b$/.test(e)&&(e="(?:"+e+")"),e||""}function u(e,t,n){return e=o(e),t=o(t),n?(e=t+e,e&&e[e.length-1]!="$"&&(e+="$")):(e+=t,e&&e[0]!="^"&&(e="^"+e)),new RegExp(e)}function a(e){e.scope||(e.scope=t||"_"),t=e.scope,n[t]||(n[t]=[],r[t]={});var o=r[t];if(e.name){var a=o[e.name];a&&i.unregister(a),o[e.name]=e}n[t].push(e),e.tabTrigger&&!e.trigger&&(!e.guard&&/^\w/.test(e.tabTrigger)&&(e.guard="\\b"),e.trigger=s.escapeRegExp(e.tabTrigger)),e.startRe=u(e.trigger,e.guard,!0),e.triggerRe=new RegExp(e.trigger,"",!0),e.endRe=u(e.endTrigger,e.endGuard,!0),e.endTriggerRe=new RegExp(e.endTrigger,"",!0)}var n=this.snippetMap,r=this.snippetNameMap,i=this;e||(e=[]),e&&e.content?a(e):Array.isArray(e)&&e.forEach(a),this._signal("registerSnippets",{scope:t})},this.unregister=function(e,t){function i(e){var i=r[e.scope||t];if(i&&i[e.name]){delete i[e.name];var s=n[e.scope||t],o=s&&s.indexOf(e);o>=0&&s.splice(o,1)}}var n=this.snippetMap,r=this.snippetNameMap;e.content?i(e):Array.isArray(e)&&e.forEach(i)},this.parseSnippetFile=function(e){e=e.replace(/\r/g,"");var t=[],n={},r=/^#.*|^({[\s\S]*})\s*$|^(\S+) (.*)$|^((?:\n*\t.*)+)/gm,i;while(i=r.exec(e)){if(i[1])try{n=JSON.parse(i[1]),t.push(n)}catch(s){}if(i[4])n.content=i[4].replace(/^\t/gm,""),t.push(n),n={};else{var o=i[2],u=i[3];if(o=="regex"){var a=/\/((?:[^\/\\]|\\.)*)|$/g;n.guard=a.exec(u)[1],n.trigger=a.exec(u)[1],n.endTrigger=a.exec(u)[1],n.endGuard=a.exec(u)[1]}else o=="snippet"?(n.tabTrigger=u.match(/^\S*/)[0],n.name||(n.name=u)):n[o]=u}}return t},this.getSnippetByName=function(e,t){var n=this.snippetNameMap,r;return this.getActiveScopes(t).some(function(t){var i=n[t];return i&&(r=i[e]),!!r},this),r}}).call(c.prototype);var h=function(e){if(e.tabstopManager)return e.tabstopManager;e.tabstopManager=this,this.$onChange=this.onChange.bind(this),this.$onChangeSelection=s.delayedCall(this.onChangeSelection.bind(this)).schedule,this.$onChangeSession=this.onChangeSession.bind(this),this.$onAfterExec=this.onAfterExec.bind(this),this.attach(e)};(function(){this.attach=function(e){this.index=0,this.ranges=[],this.tabstops=[],this.$openTabstops=null,this.selectedTabstop=null,this.editor=e,this.editor.on("change",this.$onChange),this.editor.on("changeSelection",this.$onChangeSelection),this.editor.on("changeSession",this.$onChangeSession),this.editor.commands.on("afterExec",this.$onAfterExec),this.editor.keyBinding.addKeyboardHandler(this.keyboardHandler)},this.detach=function(){this.tabstops.forEach(this.removeTabstopMarkers,this),this.ranges=null,this.tabstops=null,this.selectedTabstop=null,this.editor.removeListener("change",this.$onChange),this.editor.removeListener("changeSelection",this.$onChangeSelection),this.editor.removeListener("changeSession",this.$onChangeSession),this.editor.commands.removeListener("afterExec",this.$onAfterExec),this.editor.keyBinding.removeKeyboardHandler(this.keyboardHandler),this.editor.tabstopManager=null,this.editor=null},this.onChange=function(e){var t=e.data.range,n=e.data.action[0]=="r",r=t.start,i=t.end,s=r.row,o=i.row,u=o-s,a=i.column-r.column;n&&(u=-u,a=-a);if(!this.$inChange&&n){var f=this.selectedTabstop,c=f&&!f.some(function(e){return l(e.start,r)<=0&&l(e.end,i)>=0});if(c)return this.detach()}var h=this.ranges;for(var p=0;p<h.length;p++){var d=h[p];if(d.end.row<r.row)continue;if(n&&l(r,d.start)<0&&l(i,d.end)>0){this.removeRange(d),p--;continue}d.start.row==s&&d.start.column>r.column&&(d.start.column+=a),d.end.row==s&&d.end.column>=r.column&&(d.end.column+=a),d.start.row>=s&&(d.start.row+=u),d.end.row>=s&&(d.end.row+=u),l(d.start,d.end)>0&&this.removeRange(d)}h.length||this.detach()},this.updateLinkedFields=function(){var e=this.selectedTabstop;if(!e||!e.hasLinkedRanges)return;this.$inChange=!0;var n=this.editor.session,r=n.getTextRange(e.firstNonLinked);for(var i=e.length;i--;){var s=e[i];if(!s.linked)continue;var o=t.snippetManager.tmStrFormat(r,s.original);n.replace(s,o)}this.$inChange=!1},this.onAfterExec=function(e){e.command&&!e.command.readOnly&&this.updateLinkedFields()},this.onChangeSelection=function(){if(!this.editor)return;var e=this.editor.selection.lead,t=this.editor.selection.anchor,n=this.editor.selection.isEmpty();for(var r=this.ranges.length;r--;){if(this.ranges[r].linked)continue;var i=this.ranges[r].contains(e.row,e.column),s=n||this.ranges[r].contains(t.row,t.column);if(i&&s)return}this.detach()},this.onChangeSession=function(){this.detach()},this.tabNext=function(e){var t=this.tabstops.length,n=this.index+(e||1);n=Math.min(Math.max(n,1),t),n==t&&(n=0),this.selectTabstop(n),n===0&&this.detach()},this.selectTabstop=function(e){this.$openTabstops=null;var t=this.tabstops[this.index];t&&this.addTabstopMarkers(t),this.index=e,t=this.tabstops[this.index];if(!t||!t.length)return;this.selectedTabstop=t;if(!this.editor.inVirtualSelectionMode){var n=this.editor.multiSelect;n.toSingleRange(t.firstNonLinked.clone());for(var r=t.length;r--;){if(t.hasLinkedRanges&&t[r].linked)continue;n.addRange(t[r].clone(),!0)}n.ranges[0]&&n.addRange(n.ranges[0].clone())}else this.editor.selection.setRange(t.firstNonLinked);this.editor.keyBinding.addKeyboardHandler(this.keyboardHandler)},this.addTabstops=function(e,t,n){this.$openTabstops||(this.$openTabstops=[]);if(!e[0]){var r=o.fromPoints(n,n);v(r.start,t),v(r.end,t),e[0]=[r],e[0].index=0}var i=this.index,s=[i+1,0],u=this.ranges;e.forEach(function(e,n){var r=this.$openTabstops[n]||e;for(var i=e.length;i--;){var a=e[i],f=o.fromPoints(a.start,a.end||a.start);d(f.start,t),d(f.end,t),f.original=a,f.tabstop=r,u.push(f),r!=e?r.unshift(f):r[i]=f,a.fmtString?(f.linked=!0,r.hasLinkedRanges=!0):r.firstNonLinked||(r.firstNonLinked=f)}r.firstNonLinked||(r.hasLinkedRanges=!1),r===e&&(s.push(r),this.$openTabstops[n]=r),this.addTabstopMarkers(r)},this),s.length>2&&(this.tabstops.length&&s.push(s.splice(2,1)[0]),this.tabstops.splice.apply(this.tabstops,s))},this.addTabstopMarkers=function(e){var t=this.editor.session;e.forEach(function(e){e.markerId||(e.markerId=t.addMarker(e,"ace_snippet-marker","text"))})},this.removeTabstopMarkers=function(e){var t=this.editor.session;e.forEach(function(e){t.removeMarker(e.markerId),e.markerId=null})},this.removeRange=function(e){var t=e.tabstop.indexOf(e);e.tabstop.splice(t,1),t=this.ranges.indexOf(e),this.ranges.splice(t,1),this.editor.session.removeMarker(e.markerId),e.tabstop.length||(t=this.tabstops.indexOf(e.tabstop),t!=-1&&this.tabstops.splice(t,1),this.tabstops.length||this.detach())},this.keyboardHandler=new a,this.keyboardHandler.bindKeys({Tab:function(e){if(t.snippetManager&&t.snippetManager.expandWithTab(e))return;e.tabstopManager.tabNext(1)},"Shift-Tab":function(e){e.tabstopManager.tabNext(-1)},Esc:function(e){e.tabstopManager.detach()},Return:function(e){return!1}})}).call(h.prototype);var p={};p.onChange=u.prototype.onChange,p.setPosition=function(e,t){this.pos.row=e,this.pos.column=t},p.update=function(e,t,n){this.$insertRight=n,this.pos=e,this.onChange(t)};var d=function(e,t){e.row==0&&(e.column+=t.column),e.row+=t.row},v=function(e,t){e.row==t.row&&(e.column-=t.column),e.row-=t.row};e("./lib/dom").importCssString(".ace_snippet-marker {    -moz-box-sizing: border-box;    box-sizing: border-box;    background: rgba(194, 193, 208, 0.09);    border: 1px dotted rgba(211, 208, 235, 0.62);    position: absolute;}"),t.snippetManager=new c;var m=e("./editor").Editor;(function(){this.insertSnippet=function(e,n){return t.snippetManager.insertSnippet(this,e,n)},this.expandSnippet=function(e){return t.snippetManager.expandWithTab(this,e)}}).call(m.prototype)}),ace.define("ace/ext/emmet",["require","exports","module","ace/keyboard/hash_handler","ace/editor","ace/snippets","ace/range","resources","resources","range","tabStops","resources","utils","actions","ace/config","ace/config"],function(e,t,n){"use strict";function f(){}var r=e("ace/keyboard/hash_handler").HashHandler,i=e("ace/editor").Editor,s=e("ace/snippets").snippetManager,o=e("ace/range").Range,u,a;f.prototype={setupContext:function(e){this.ace=e,this.indentation=e.session.getTabString(),u||(u=window.emmet),u.require("resources").setVariable("indentation",this.indentation),this.$syntax=null,this.$syntax=this.getSyntax()},getSelectionRange:function(){var e=this.ace.getSelectionRange(),t=this.ace.session.doc;return{start:t.positionToIndex(e.start),end:t.positionToIndex(e.end)}},createSelection:function(e,t){var n=this.ace.session.doc;this.ace.selection.setRange({start:n.indexToPosition(e),end:n.indexToPosition(t)})},getCurrentLineRange:function(){var e=this.ace,t=e.getCursorPosition().row,n=e.session.getLine(t).length,r=e.session.doc.positionToIndex({row:t,column:0});return{start:r,end:r+n}},getCaretPos:function(){var e=this.ace.getCursorPosition();return this.ace.session.doc.positionToIndex(e)},setCaretPos:function(e){var t=this.ace.session.doc.indexToPosition(e);this.ace.selection.moveToPosition(t)},getCurrentLine:function(){var e=this.ace.getCursorPosition().row;return this.ace.session.getLine(e)},replaceContent:function(e,t,n,r){n==null&&(n=t==null?this.getContent().length:t),t==null&&(t=0);var i=this.ace,u=i.session.doc,a=o.fromPoints(u.indexToPosition(t),u.indexToPosition(n));i.session.remove(a),a.end=a.start,e=this.$updateTabstops(e),s.insertSnippet(i,e)},getContent:function(){return this.ace.getValue()},getSyntax:function(){if(this.$syntax)return this.$syntax;var e=this.ace.session.$modeId.split("/").pop();if(e=="html"||e=="php"){var t=this.ace.getCursorPosition(),n=this.ace.session.getState(t.row);typeof n!="string"&&(n=n[0]),n&&(n=n.split("-"),n.length>1?e=n[0]:e=="php"&&(e="html"))}return e},getProfileName:function(){switch(this.getSyntax()){case"css":return"css";case"xml":case"xsl":return"xml";case"html":var e=u.require("resources").getVariable("profile");return e||(e=this.ace.session.getLines(0,2).join("").search(/<!DOCTYPE[^>]+XHTML/i)!=-1?"xhtml":"html"),e}return"xhtml"},prompt:function(e){return prompt(e)},getSelection:function(){return this.ace.session.getTextRange()},getFilePath:function(){return""},$updateTabstops:function(e){var t=1e3,n=0,r=null,i=u.require("range"),s=u.require("tabStops"),o=u.require("resources").getVocabulary("user"),a={tabstop:function(e){var o=parseInt(e.group,10),u=o===0;u?o=++n:o+=t;var f=e.placeholder;f&&(f=s.processText(f,a));var l="${"+o+(f?":"+f:"")+"}";return u&&(r=i.create(e.start,l)),l},escape:function(e){return e=="$"?"\\$":e=="\\"?"\\\\":e}};return e=s.processText(e,a),o.variables.insert_final_tabstop&&!/\$\{0\}$/.test(e)?e+="${0}":r&&(e=u.require("utils").replaceSubstring(e,"${0}",r)),e}};var l={expand_abbreviation:{mac:"ctrl+alt+e",win:"alt+e"},match_pair_outward:{mac:"ctrl+d",win:"ctrl+,"},match_pair_inward:{mac:"ctrl+j",win:"ctrl+shift+0"},matching_pair:{mac:"ctrl+alt+j",win:"alt+j"},next_edit_point:"alt+right",prev_edit_point:"alt+left",toggle_comment:{mac:"command+/",win:"ctrl+/"},split_join_tag:{mac:"shift+command+'",win:"shift+ctrl+`"},remove_tag:{mac:"command+'",win:"shift+ctrl+;"},evaluate_math_expression:{mac:"shift+command+y",win:"shift+ctrl+y"},increment_number_by_1:"ctrl+up",decrement_number_by_1:"ctrl+down",increment_number_by_01:"alt+up",decrement_number_by_01:"alt+down",increment_number_by_10:{mac:"alt+command+up",win:"shift+alt+up"},decrement_number_by_10:{mac:"alt+command+down",win:"shift+alt+down"},select_next_item:{mac:"shift+command+.",win:"shift+ctrl+."},select_previous_item:{mac:"shift+command+,",win:"shift+ctrl+,"},reflect_css_value:{mac:"shift+command+r",win:"shift+ctrl+r"},encode_decode_data_url:{mac:"shift+ctrl+d",win:"ctrl+'"},expand_abbreviation_with_tab:"Tab",wrap_with_abbreviation:{mac:"shift+ctrl+a",win:"shift+ctrl+a"}},c=new f;t.commands=new r,t.runEmmetCommand=function(e){try{c.setupContext(e);if(c.getSyntax()=="php")return!1;var t=u.require("actions");if(this.action=="expand_abbreviation_with_tab"&&!e.selection.isEmpty())return!1;if(this.action=="wrap_with_abbreviation")return setTimeout(function(){t.run("wrap_with_abbreviation",c)},0);var n=e.selection.lead,r=e.session.getTokenAt(n.row,n.column);if(r&&/\btag\b/.test(r.type))return!1;var i=t.run(this.action,c)}catch(s){e._signal("changeStatus",typeof s=="string"?s:s.message),console.log(s),i=!1}return i};for(var h in l)t.commands.addCommand({name:"emmet:"+h,action:h,bindKey:l[h],exec:t.runEmmetCommand,multiSelectAction:"forEach"});t.updateCommands=function(e,n){n?e.keyBinding.addKeyboardHandler(t.commands):e.keyBinding.removeKeyboardHandler(t.commands)},t.isSupportedMode=function(e){return e&&/css|less|scss|sass|stylus|html|php|twig|ejs|handlebars/.test(e)};var p=function(n,r){var i=r;if(!i)return;var s=t.isSupportedMode(i.session.$modeId);n.enableEmmet===!1&&(s=!1),s&&typeof a=="string"&&e("ace/config").loadModule(a,function(){a=null}),t.updateCommands(i,s)};t.AceEmmetEditor=f,e("ace/config").defineOptions(i.prototype,"editor",{enableEmmet:{set:function(e){this[e?"on":"removeListener"]("changeMode",p),p({enableEmmet:!!e},this)},value:!0}}),t.setCore=function(e){typeof e=="string"?a=e:u=e}});
                (function() {
                    ace.require(["ace/ext/emmet"], function() {});
                })();
            
//@license-end
