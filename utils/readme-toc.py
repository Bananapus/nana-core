import re

def generate_toc(md_file_path):
    toc_lines = ['<details>', '  <summary>Table of Contents</summary>', '  <ol>']
    current_level = 0

    with open(md_file_path, 'r') as md_file:
        for line in md_file:
            match = re.match(r'^(#{2,6}) (.*)', line)
            if match:
                level = len(match.group(1)) - 1
                heading = match.group(2).strip()
                anchor = re.sub(r'[^0-9a-zA-Z\- ]', '', heading).replace(' ', '-').lower()

                while level < current_level:
                    toc_lines.append('  ' * current_level + '</ul>')
                    current_level -= 1
                while level > current_level:
                    if current_level > 0:
                        toc_lines.append('  ' * current_level + '<ul>')
                    current_level += 1
                
                if level == 1:
                    toc_lines.append(f'    <li><a href="#{anchor}">{heading}</a></li>')
                else:
                    toc_lines.append('  ' * current_level + f'<li><a href="#{anchor}">{heading}</a></li>')

    while current_level > 0:
        toc_lines.append('  ' * current_level + '</ul>')
        current_level -= 1

    toc_lines.append('  </ol>')
    toc_lines.append('</details>')

    return '\n'.join(toc_lines)

md_file_path = 'README.md'
toc = generate_toc(md_file_path)
print(toc)
