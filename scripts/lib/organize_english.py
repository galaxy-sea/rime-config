"""保留 Rime 词库头和分类，忽略单词大小写，按编码及权重合并词条。"""
import os
import re
import sys
import tempfile
from datetime import datetime
from decimal import Decimal, InvalidOperation
from pathlib import Path


def load_standard_words(path):
    lines = path.read_text(encoding='utf-8').splitlines()
    boundary = next((i for i, line in enumerate(lines) if line.strip() == '...'), None)
    if boundary is None:
        raise ValueError('标准英文词库缺少正文分隔符')
    words = set()
    for line in lines[boundary + 1:]:
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        fields = line.split('\t')
        word = fields[0].strip()
        # 只采用自然拼写编码，避免把只能通过缩写输入的词当作标准完整词。
        if word and (len(fields) == 1 or fields[1].strip().lower() == word.lower()):
            words.add(word.lower())
    return words


def organize(source, standard_words=None):
    lines = source.splitlines(keepends=True)
    boundary = next((i for i, line in enumerate(lines)
                     if line.strip() == '...'), None)
    if boundary is None:
        raise ValueError('词库缺少正文分隔符 ...')
    header = ''.join(lines[:boundary + 1]).rstrip('\r\n') + '\n'
    titles = ('冲突的', '启用的', '未启用的')
    # 每个大分组保留自己的子分类顺序；空分类也保留。
    categories = [[None] for _ in titles]
    notes = {(index, None): [] for index in range(3)}
    section = 1
    category = None
    preamble = []
    seen_section = False
    groups = {}
    for line_number, line in enumerate(lines[boundary + 1:], boundary + 2):
        text = line.strip()
        if not text:
            continue
        if text in {'### ' + title for title in titles}:
            section = titles.index(text[4:])
            category = None
            seen_section = True
            continue
        if re.match(r'^####\s', text):
            category = text
            if category not in categories[section]:
                categories[section].append(category)
            notes.setdefault((section, category), [])
            continue
        enabled = not text.startswith('#')
        entry = text if enabled else text[1:].lstrip()
        # 技术术语可以包含空格、中文、斜杠等；有编码时必须用 TAB 分列。
        fields = entry.split('\t')
        if len(fields) == 3 and all(field.strip() for field in fields):
            word, code, weight = fields
        else:
            if not enabled and '\t' not in entry and not re.fullmatch(
                    r'[A-Za-z][A-Za-z0-9_-]*', entry):
                if not seen_section and category is None:
                    preamble.append(text)
                else:
                    notes.setdefault((section, category), []).append(text)
                continue
            raise ValueError(
                f'第 {line_number} 行词条必须用两个 Tab 分隔为三个非空列'
                '（词语、编码、权重），未修改文件：' + text
            )
        # 本词库使用字母编码；纯数字编码通常是缺少 Tab 后把权重错当编码。
        if code.strip().isdecimal():
            raise ValueError(
                f'第 {line_number} 行编码为纯数字，请检查是否把权重误写到编码列，'
                f'未修改文件：{text}'
            )
        try:
            numeric_weight = Decimal(weight)
            if not numeric_weight.is_finite():
                raise InvalidOperation
        except InvalidOperation:
            raise ValueError(f'第 {line_number} 行权重必须是有限数字，未修改文件：{text}')
        # 标准词库已有的未启用普通词不再收集；启用项及快捷编码仍保留。
        if (not enabled and standard_words and word.lower() in standard_words
                and code.lower() == word.lower()):
            continue
        record = (enabled, word, code, weight, category)
        variants = groups.setdefault(word.lower(), {})
        identity = (word.lower(), code)
        previous = variants.get(identity)
        # 忽略单词大小写；保留最高权重的原始写法，权重相同时启用项优先。
        if (previous is None or numeric_weight > Decimal(previous[3])
                or (numeric_weight == Decimal(previous[3]) and enabled and not previous[0])):
            variants[identity] = record

    sections = [[], [], []]
    for key in sorted(groups):
        variants = groups[key]
        for identity in sorted(variants):
            record = variants[identity]
            index = 1 if record[0] else 2
            sections[index].append(record)
    output = header
    if preamble:
        output += '\n'.join(dict.fromkeys(preamble)) + '\n'
    for index, (title, records) in enumerate(zip(titles, sections)):
        output += '\n### ' + title + '\n'
        for record in records:
            if record[4] not in categories[index]:
                categories[index].append(record[4])
        for label in categories[index]:
            if label is not None:
                output += '\n' + label + '\n'
            for note in dict.fromkeys(notes.get((index, label), [])):
                output += note + '\n'
            for enabled, word, code, weight, record_category in records:
                if record_category == label:
                    output += ('' if enabled else '# ') + '\t'.join((word, code, weight)) + '\n'
    return output


def require_no_conflicts(result, path):
    section = result.split('### 冲突的\n', 1)[1].split('### 启用的\n', 1)[0]
    # 空子分类及说明注释不算冲突词条。
    if any('\t' in line and not line.startswith('####')
           for line in section.splitlines()):
        raise ValueError(
            f'已归类，但仍有大小写冲突，停止部署。请处理 {path} 的「冲突的」分组，'
            '每个单词仅保留一种大小写；仅添加注释不能消除冲突。'
        )


def main():
    path = Path(sys.argv[1]).resolve(strict=True)
    original = path.read_bytes()
    standard_path = (Path(sys.argv[3]).expanduser() if len(sys.argv) > 3
                     else Path.home() / '.local/share/fcitx5/rime/en_dicts/en.dict.yaml')
    try:
        standard_words = load_standard_words(standard_path)
    except (OSError, ValueError, UnicodeError) as error:
        print(f'标准英文词库不可用，跳过标准词对比：{error}', file=sys.stderr)
        standard_words = set()
    result = organize(original.decode('utf-8'), standard_words).encode('utf-8')
    if result == original:
        require_no_conflicts(result.decode('utf-8'), path)
        print('归类完成：内容没有变化。')
        return
    backup_dir = Path(sys.argv[2])
    backup_dir.mkdir(parents=True, exist_ok=True)
    backup = backup_dir / (path.name + '.' + datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
    backup.write_bytes(original)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as file:
            temporary = Path(file.name)
            file.write(result)
        temporary.chmod(path.stat().st_mode & 0o777)
        if path.read_bytes() != original:
            raise ValueError('整理期间文件有新增或修改，请停止输入后重试。')
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    print('归类完成：已合并重复项，并按冲突、启用、未启用分组。')
    print('原文件备份：' + str(backup))
    require_no_conflicts(result.decode('utf-8'), path)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, UnicodeError) as error:
        print('归类失败：' + str(error), file=sys.stderr)
        sys.exit(1)
