def main():
    import ubelt as ub
    import xdev
    fpath = ub.Path('$HOME/code/transcrypt/transcrypt').expand()
    text = fpath.read_text()
    lines = text.split('\n')

    tabstop = 4
    indent_pat = xdev.Pattern.from_regex(r'(\s*)(.*)')
    space_pat = xdev.Pattern.from_regex(r' ' * tabstop)

    in_usage = 0
    new_lines = []
    for line in lines:
        if 'cat <<-EOF' == line.strip():
            in_usage = True
        if 'EOF' == line.strip():
            in_usage = False
        indent, suffix = indent_pat.match(line).groups()
        hist = ub.dict_hist(indent)
        ntabs = hist.get('\t', 0)
        if in_usage:
            # Only have 2 leading tabs in the usage part
            new_indent = space_pat.sub('\t', indent, count=(2 - ntabs))
        else:
            new_indent = space_pat.sub('\t', indent)
        new_line = new_indent + suffix
        new_lines.append(new_line)
