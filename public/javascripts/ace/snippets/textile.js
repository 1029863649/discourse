 //@license magnet:?xt=urn:btih:cf05388f2679ee054f2beb29a391d25f4e673ac3&dn=gpl-2.0.txt GPL-v2-or-Later
ace.define("ace/snippets/textile",["require","exports","module"],function(e,t,n){"use strict";t.snippetText='# Jekyll post header\nsnippet header\n	---\n	title: ${1:title}\n	layout: post\n	date: ${2:date} ${3:hour:minute:second} -05:00\n	---\n\n# Image\nsnippet img\n	!${1:url}(${2:title}):${3:link}!\n\n# Table\nsnippet |\n	|${1}|${2}\n\n# Link\nsnippet link\n	"${1:link text}":${2:url}\n\n# Acronym\nsnippet (\n	(${1:Expand acronym})${2}\n\n# Footnote\nsnippet fn\n	[${1:ref number}] ${3}\n\n	fn$1. ${2:footnote}\n	\n',t.scope="textile"})
//@license-end
