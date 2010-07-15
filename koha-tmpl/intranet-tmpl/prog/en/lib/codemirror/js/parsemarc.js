Editor.Parser = (function() {
	function isWhiteSpace(ch) {
		// The messy regexp is because IE's regexp matcher is of the
		// opinion that non-breaking spaces are no whitespace.
		return ch != "\n" && /^[\s\u00a0]*$/.test(ch);
	}

	var tokenizeMARC = (function() {
		function normal(source, setState) {
			var ch = source.next();
			if (ch == '$' || ch == '|') {
				if (source.applies(matcher(/[a-z0-9]/)) && source.next() && source.applies(isWhiteSpace)) {
					return 'marc-subfield';
				} else {
					return 'marc-word';
				}
			} else if (ch.match(/[0-9]/)) {
				// This and the next block are muddled because tags are ^[0-9]{3} and indicators are [0-9_]{2}.
				var length = 1;
				while (source.applies(matcher(/[0-9]/))) {
					source.next();
					length++;
				}

				if (length == 1 && source.lookAhead('_')) {
					source.next();
					return 'marc-indicator';
				}

				if (source.applies(isWhiteSpace) && length == 2) {
					return 'marc-indicator';
				} else if (source.applies(isWhiteSpace) && length == 3) {
					return 'marc-tag';
				} else {
					return 'marc-word';
				}
			} else if (ch == '_') {
				if (source.applies(matcher(/[0-9_]/)) && source.next() && source.applies(isWhiteSpace)) {
					return 'marc-indicator';
				} else {
					return 'marc-word';
				}
			} else {
				source.nextWhile(matcher(/[^\$|\n]/));
				return 'marc-word';
			}
		}

		return function(source, startState) {
			return tokenizer(source, startState || normal);
		};
	})();

	function indentMARC(context) {
		return function(nextChars) {
			return 0;
		};
	}

	function parseMARC(source) {
		var tokens = tokenizeMARC(source);
		var context = null, indent = 0, col = 0;

		var iter = {
			next: function() {
				var token = tokens.next(), type = token.style, content = token.content, width = token.value.length;

				if (content == "\n") {
					token.indentation = indentMARC(context);
					indent = col = 0;
					if (context && context.align === null) { context.align = false }
				} else if (type == "whitespace" && col === 0) {
					indent = width;
				} else if (type != "sp-comment" && context && context.align === null) {
					context.align = true;
				}

				if ((type == 'marc-tag' && col != 0) || (type == 'marc-indicator' && col != 4)) {
					token.style = 'marc-word';
				}

				if (content != "\n") { col += width }

				return token;
			},

			copy: function() {
				var _context = context, _indent = indent, _col = col, _tokenState = tokens.state;
				return function(source) {
					tokens = tokenizeMARC(source, _tokenState);
					context = _context;
					indent = _indent;
					col = _col;
					return iter;
				};
			}
		};
		return iter;
	}

	return {make: parseMARC, electricChars: "}]"};
})();
