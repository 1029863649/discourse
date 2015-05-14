ace.define("ace/mode/clojure_highlight_rules",["require","exports","module","ace/lib/oop","ace/mode/text_highlight_rules"],function(e,t,n){"use strict";var r=e("../lib/oop"),i=e("./text_highlight_rules").TextHighlightRules,s=function(){var e="* *1 *2 *3 *agent* *allow-unresolved-vars* *assert* *clojure-version* *command-line-args* *compile-files* *compile-path* *e *err* *file* *flush-on-newline* *in* *macro-meta* *math-context* *ns* *out* *print-dup* *print-length* *print-level* *print-meta* *print-readably* *read-eval* *source-path* *use-context-classloader* *warn-on-reflection* + - -> ->> .. / < <= = == > &gt; >= &gt;= accessor aclone add-classpath add-watch agent agent-errors aget alength alias all-ns alter alter-meta! alter-var-root amap ancestors and apply areduce array-map aset aset-boolean aset-byte aset-char aset-double aset-float aset-int aset-long aset-short assert assoc assoc! assoc-in associative? atom await await-for await1 bases bean bigdec bigint binding bit-and bit-and-not bit-clear bit-flip bit-not bit-or bit-set bit-shift-left bit-shift-right bit-test bit-xor boolean boolean-array booleans bound-fn bound-fn* butlast byte byte-array bytes cast char char-array char-escape-string char-name-string char? chars chunk chunk-append chunk-buffer chunk-cons chunk-first chunk-next chunk-rest chunked-seq? class class? clear-agent-errors clojure-version coll? comment commute comp comparator compare compare-and-set! compile complement concat cond condp conj conj! cons constantly construct-proxy contains? count counted? create-ns create-struct cycle dec decimal? declare definline defmacro defmethod defmulti defn defn- defonce defstruct delay delay? deliver deref derive descendants destructure disj disj! dissoc dissoc! distinct distinct? doall doc dorun doseq dosync dotimes doto double double-array doubles drop drop-last drop-while empty empty? ensure enumeration-seq eval even? every? false? ffirst file-seq filter find find-doc find-ns find-var first float float-array float? floats flush fn fn? fnext for force format future future-call future-cancel future-cancelled? future-done? future? gen-class gen-interface gensym get get-in get-method get-proxy-class get-thread-bindings get-validator hash hash-map hash-set identical? identity if-let if-not ifn? import in-ns inc init-proxy instance? int int-array integer? interleave intern interpose into into-array ints io! isa? iterate iterator-seq juxt key keys keyword keyword? last lazy-cat lazy-seq let letfn line-seq list list* list? load load-file load-reader load-string loaded-libs locking long long-array longs loop macroexpand macroexpand-1 make-array make-hierarchy map map? mapcat max max-key memfn memoize merge merge-with meta method-sig methods min min-key mod name namespace neg? newline next nfirst nil? nnext not not-any? not-empty not-every? not= ns ns-aliases ns-imports ns-interns ns-map ns-name ns-publics ns-refers ns-resolve ns-unalias ns-unmap nth nthnext num number? odd? or parents partial partition pcalls peek persistent! pmap pop pop! pop-thread-bindings pos? pr pr-str prefer-method prefers primitives-classnames print print-ctor print-doc print-dup print-method print-namespace-doc print-simple print-special-doc print-str printf println println-str prn prn-str promise proxy proxy-call-with-super proxy-mappings proxy-name proxy-super push-thread-bindings pvalues quot rand rand-int range ratio? rational? rationalize re-find re-groups re-matcher re-matches re-pattern re-seq read read-line read-string reduce ref ref-history-count ref-max-history ref-min-history ref-set refer refer-clojure release-pending-sends rem remove remove-method remove-ns remove-watch repeat repeatedly replace replicate require reset! reset-meta! resolve rest resultset-seq reverse reversible? rseq rsubseq second select-keys send send-off seq seq? seque sequence sequential? set set-validator! set? short short-array shorts shutdown-agents slurp some sort sort-by sorted-map sorted-map-by sorted-set sorted-set-by sorted? special-form-anchor special-symbol? split-at split-with str stream? string? struct struct-map subs subseq subvec supers swap! symbol symbol? sync syntax-symbol-anchor take take-last take-nth take-while test the-ns time to-array to-array-2d trampoline transient tree-seq true? type unchecked-add unchecked-dec unchecked-divide unchecked-inc unchecked-multiply unchecked-negate unchecked-remainder unchecked-subtract underive unquote unquote-splicing update-in update-proxy use val vals var-get var-set var? vary-meta vec vector vector? when when-first when-let when-not while with-bindings with-bindings* with-in-str with-loading-context with-local-vars with-meta with-open with-out-str with-precision xml-seq zero? zipmap",t="throw try var def do fn if let loop monitor-enter monitor-exit new quote recur set!",n="true false nil",r=this.createKeywordMapper({keyword:t,"constant.language":n,"support.function":e},"identifier",!1," ");this.$rules={start:[{token:"comment",regex:";.*$"},{token:"keyword",regex:"[\\(|\\)]"},{token:"keyword",regex:"[\\'\\(]"},{token:"keyword",regex:"[\\[|\\]]"},{token:"keyword",regex:"[\\{|\\}|\\#\\{|\\#\\}]"},{token:"keyword",regex:"[\\&]"},{token:"keyword",regex:"[\\#\\^\\{]"},{token:"keyword",regex:"[\\%]"},{token:"keyword",regex:"[@]"},{token:"constant.numeric",regex:"0[xX][0-9a-fA-F]+\\b"},{token:"constant.numeric",regex:"[+-]?\\d+(?:(?:\\.\\d*)?(?:[eE][+-]?\\d+)?)?\\b"},{token:"constant.language",regex:"[!|\\$|%|&|\\*|\\-\\-|\\-|\\+\\+|\\+||=|!=|<=|>=|<>|<|>|!|&&]"},{token:r,regex:"[a-zA-Z_$][a-zA-Z0-9_$\\-]*\\b"},{token:"string",regex:'"',next:"string"},{token:"constant",regex:/:[^()\[\]{}'"\^%`,;\s]+/},{token:"string.regexp",regex:'/#"(?:\\.|(?:\\")|[^""\n])*"/g'}],string:[{token:"constant.language.escape",regex:"\\\\.|\\\\$"},{token:"string",regex:'[^"\\\\]+'},{token:"string",regex:'"',next:"start"}]}};r.inherits(s,i),t.ClojureHighlightRules=s}),ace.define("ace/mode/matching_parens_outdent",["require","exports","module","ace/range"],function(e,t,n){"use strict";var r=e("../range").Range,i=function(){};(function(){this.checkOutdent=function(e,t){return/^\s+$/.test(e)?/^\s*\)/.test(t):!1},this.autoOutdent=function(e,t){var n=e.getLine(t),i=n.match(/^(\s*\))/);if(!i)return 0;var s=i[1].length,o=e.findMatchingBracket({row:t,column:s});if(!o||o.row==t)return 0;var u=this.$getIndent(e.getLine(o.row));e.replace(new r(t,0,t,s-1),u)},this.$getIndent=function(e){var t=e.match(/^(\s+)/);return t?t[1]:""}}).call(i.prototype),t.MatchingParensOutdent=i}),ace.define("ace/mode/clojure",["require","exports","module","ace/lib/oop","ace/mode/text","ace/mode/clojure_highlight_rules","ace/mode/matching_parens_outdent"],function(e,t,n){"use strict";var r=e("../lib/oop"),i=e("./text").Mode,s=e("./clojure_highlight_rules").ClojureHighlightRules,o=e("./matching_parens_outdent").MatchingParensOutdent,u=function(){this.HighlightRules=s,this.$outdent=new o};r.inherits(u,i),function(){this.lineCommentStart=";",this.minorIndentFunctions=["defn","defn-","defmacro","def","deftest","testing"],this.$toIndent=function(e){return e.split("").map(function(e){return/\s/.exec(e)?e:" "}).join("")},this.$calculateIndent=function(e,t){var n=this.$getIndent(e),r=0,i,s;for(var o=e.length-1;o>=0;o--){s=e[o],s==="("?(r--,i=!0):s==="("||s==="["||s==="{"?(r--,i=!1):(s===")"||s==="]"||s==="}")&&r++;if(r<0)break}if(!(r<0&&i))return r<0&&!i?this.$toIndent(e.substring(0,o+1)):r>0?(n=n.substring(0,n.length-t.length),n):n;o+=1;var u=o,a="";for(;;){s=e[o];if(s===" "||s==="	")return this.minorIndentFunctions.indexOf(a)!==-1?this.$toIndent(e.substring(0,u-1)+t):this.$toIndent(e.substring(0,o+1));if(s===undefined)return this.$toIndent(e.substring(0,u-1)+t);a+=e[o],o++}},this.getNextLineIndent=function(e,t,n){return this.$calculateIndent(t,n)},this.checkOutdent=function(e,t,n){return this.$outdent.checkOutdent(t,n)},this.autoOutdent=function(e,t,n){this.$outdent.autoOutdent(t,n)},this.$id="ace/mode/clojure"}.call(u.prototype),t.Mode=u})