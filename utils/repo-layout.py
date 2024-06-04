import os

ignored = [".git/", "node_modules/", ".env", "lib/", "broadcast/", "out/", "cache/"]

def generate_diagram(path: str, prefix=""):
    contents = os.listdir(path)
    contents.sort()
    for index, content in enumerate(contents):
        content_path = os.path.join(path, content)
        if os.path.isdir(content_path):
            content += "/"  # Add trailing slash for directories
        if index == len(contents) - 1:
            connector = "└── "
            new_prefix = prefix + "    "
        else:
            connector = "├── "
            new_prefix = prefix + "│   "

        print(prefix + connector + content)
        if os.path.isdir(content_path) and content not in ignored:
            generate_diagram(content_path, new_prefix)

if __name__ == "__main__":
    root_dir = "."
    print(os.path.basename(os.path.abspath(root_dir)) + "/")
    generate_diagram(root_dir)
