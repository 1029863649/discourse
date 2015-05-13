define("ace/mode/gcode_highlight_rules",["require","exports","module","ace/lib/oop","ace/mode/text_highlight_rules"],function(e,t,n){"use strict";var r=e("../lib/oop"),i=e("./text_highlight_rules").TextHighlightRules,s=function(){var e="IF|DO|WHILE|ENDWHILE|CALL|ENDIF|SUB|ENDSUB|GOTO|REPEAT|ENDREPEAT|CALL",t="PI",n="ATAN|ABS|ACOS|ASIN|SIN|COS|EXP|FIX|FUP|ROUND|LN|TAN",r=this.createKeywordMapper({"support.function":n,keyword:e,"constant.language":t},"identifier",!0);this.$rules={start:[{token:"comment",regex:"\\(.*\\)"},{token:"comment",regex:"([N])([0-9]+)"},{token:"string",regex:"([G])([0-9]+\\.?[0-9]?)"},{token:"string",regex:"([M])([0-9]+\\.?[0-9]?)"},{token:"constant.numeric",regex:"([-+]?([0-9]*\\.?[0-9]+\\.?))|(\\b0[xX][a-fA-F0-9]+|(\\b\\d+(\\.\\d*)?|\\.\\d+)([eE][-+]?\\d+)?)"},{token:r,regex:"[A-Z]"},{token:"keyword.operator",regex:"EQ|LT|GT|NE|GE|LE|OR|XOR"},{token:"paren.lparen",regex:"[\\[]"},{token:"paren.rparen",regex:"[\\]]"},{token:"text",regex:"\\s+"}]}};r.inherits(s,i),t.GcodeHighlightRules=s}),define("ace/mode/gcode",["require","exports","module","ace/lib/oop","ace/mode/text","ace/mode/gcode_highlight_rules","ace/range"],function(e,t,n){"use strict";var r=e("../lib/oop"),i=e("./text").Mode,s=e("./gcode_highlight_rules").GcodeHighlightRules,o=e("../range").Range,u=function(){this.HighlightRules=s};r.inherits(u,i),function(){this.$id="ace/mode/gcode"}.call(u.prototype),t.Mode=u})