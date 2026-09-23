@echo off
setlocal
set "SELF=%~f0"
set "FILE=%~f1"
powershell -NoProfile -ExecutionPolicy Bypass -STA -Command "$s=Get-Content -LiteralPath $env:SELF -Encoding UTF8; $n=[array]::IndexOf($s,'#PSSTART#')+1; & ([scriptblock]::Create((($s[$n..($s.Length-1)]) -join [char]10)))"
exit /b
#PSSTART#
Add-Type -AssemblyName System.Windows.Forms, System.Drawing, Microsoft.VisualBasic
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

try {
Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition @'
using System.Drawing;
using System.Windows.Forms;
public class FlatTable : ProfessionalColorTable {
    public Color Bg, Hov, Brd;
    public FlatTable(Color bg, Color hov, Color brd) : base() { Bg=bg; Hov=hov; Brd=brd; }
    public override Color MenuItemSelected { get { return Hov; } }
    public override Color MenuItemBorder { get { return Brd; } }
    public override Color MenuBorder { get { return Brd; } }
    public override Color ToolStripDropDownBackground { get { return Bg; } }
    public override Color ImageMarginGradientBegin { get { return Bg; } }
    public override Color ImageMarginGradientMiddle { get { return Bg; } }
    public override Color ImageMarginGradientEnd { get { return Bg; } }
    public override Color MenuStripGradientBegin { get { return Bg; } }
    public override Color MenuStripGradientEnd { get { return Bg; } }
    public override Color ToolStripBorder { get { return Brd; } }
    public override Color SeparatorDark { get { return Brd; } }
    public override Color SeparatorLight { get { return Brd; } }
}
public class FlatRend : ToolStripProfessionalRenderer {
    public Color Fg, Bg, Hov;
    public FlatRend(FlatTable t, Color fg, Color bg, Color hov) : base(t) { Fg=fg; Bg=bg; Hov=hov; }
    protected override void OnRenderItemText(ToolStripItemTextRenderEventArgs e) { e.TextColor = Fg; base.OnRenderItemText(e); }
    protected override void OnRenderMenuItemBackground(ToolStripItemRenderEventArgs e) {
        using (var b = new SolidBrush(e.Item.Selected && e.Item.Enabled ? Hov : Bg))
            e.Graphics.FillRectangle(b, new Rectangle(Point.Empty, e.Item.Size));
    }
    protected override void OnRenderToolStripBackground(ToolStripRenderEventArgs e) {
        using (var b = new SolidBrush(Bg)) e.Graphics.FillRectangle(b, e.AffectedBounds);
    }
}
'@
} catch { }

function MkColor([int]$r,[int]$g,[int]$b){ [System.Drawing.Color]::FromArgb($r,$g,$b) }
$C=@{}
function SetDark {
 $C.bg=MkColor 24 24 30; $C.panel=MkColor 36 36 44; $C.panel2=MkColor 46 46 58; $C.edit=MkColor 18 18 22
 $C.fg=MkColor 220 220 230; $C.dim=MkColor 140 140 160; $C.accent=MkColor 0 170 255; $C.hover=MkColor 60 60 78
 $C.gutter=MkColor 28 28 36; $C.gutterfg=MkColor 100 100 125; $C.border=MkColor 54 54 68; $C.field=MkColor 28 28 36
 $C.kw=MkColor 86 156 214; $C.str=MkColor 206 145 120; $C.cmt=MkColor 106 153 85
 $C.num=MkColor 181 206 168; $C.fn=MkColor 220 220 170; $C.ty=MkColor 78 201 176
}
function SetLight {
 $C.bg=MkColor 244 244 248; $C.panel=MkColor 232 232 238; $C.panel2=MkColor 218 218 226; $C.edit=MkColor 255 255 255
 $C.fg=MkColor 30 30 38; $C.dim=MkColor 110 110 128; $C.accent=MkColor 0 120 215; $C.hover=MkColor 205 214 232
 $C.gutter=MkColor 240 240 246; $C.gutterfg=MkColor 150 150 168; $C.border=MkColor 200 200 212; $C.field=MkColor 255 255 255
 $C.kw=MkColor 0 0 220; $C.str=MkColor 163 21 21; $C.cmt=MkColor 0 128 0
 $C.num=MkColor 9 134 88; $C.fn=MkColor 121 94 38; $C.ty=MkColor 43 145 175
}
SetDark

$TOKEN_RE = [regex]@'
(?<c>//[^\r\n]*|/\*[\s\S]*?\*/|\#[^\r\n]*|

'@.Trim()

function New-KwSet([string]$kw) {
    $s = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($w in $kw -split '\s+') { if ($w) { [void]$s.Add($w.ToLower()) } }
    return ,$s
}
$script:KW = @{
 js   = New-KwSet 'var let const function return if else for while do switch case break continue new this class extends import export from async await try catch finally throw typeof instanceof null undefined true false in of delete void yield super static get set'
 py   = New-KwSet 'def class return if elif else for while in not and or is none true false import from as try except finally raise with lambda yield global nonlocal pass break continue async await assert del self'
 ps   = New-KwSet 'function param return if else elseif switch foreach for while do break continue try catch finally throw begin process end filter in'
 bat  = New-KwSet 'if else for goto call set echo rem exit cd dir copy move del type'
 json = New-KwSet 'true false null'
 sql  = New-KwSet 'select from where insert into values update set delete create table drop alter index join inner left right outer on and or not null order by group having limit offset union as distinct count sum avg min max'
 cs   = New-KwSet 'using namespace class struct interface enum public private protected internal static readonly const void int string bool double float long var new return if else for foreach while do switch case break continue try catch finally throw this base null true false async await get set'
 cpp  = New-KwSet 'include define ifndef endif namespace class struct public private protected static const void int char float double long short bool return if else for while do switch case break continue try catch throw new delete this nullptr true false'
 java = New-KwSet 'package import class interface enum public private protected static final void int string boolean double float long new return if else for while do switch case break continue try catch finally throw this super null true false extends implements abstract'
}

function Get-LangFromExt([string]$path) {
    if (-not $path) { return 'plain' }
    $e = [System.IO.Path]::GetExtension($path).ToLower()
    switch ($e) {
        '.js' { 'js' }; '.jsx' { 'js' }; '.ts' { 'js' }; '.tsx' { 'js' }
        '.py' { 'py' }
        '.ps1' { 'ps' }; '.psm1' { 'ps' }
        '.bat' { 'bat' }; '.cmd' { 'bat' }
        '.json' { 'json' }
        '.sql' { 'sql' }
        '.cs' { 'cs' }
        '.cpp' { 'cpp' }; '.c' { 'cpp' }; '.h' { 'cpp' }; '.hpp' { 'cpp' }
        '.java' { 'java' }
        default { 'plain' }
    }
}

function Esc-Rtf([string]$s) {
    if (-not $s) { return '' }
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $s.ToCharArray()) {
        $code = [int]$ch
        if ($ch -eq '\') { [void]$sb.Append('\\') }
        elseif ($ch -eq '{') { [void]$sb.Append('\{') }
        elseif ($ch -eq '}') { [void]$sb.Append('\}') }
        elseif ($ch -eq "`r") { }
        elseif ($ch -eq "`n") { [void]$sb.Append('\par ') }
        elseif ($code -lt 32) { }
        elseif ($code -lt 128) { [void]$sb.Append($ch) }
        else {
            $signed = if ($code -gt 32767) { $code - 65536 } else { $code }
            [void]$sb.Append("\u$signed?")
        }
    }
    return $sb.ToString()
}

function Build-Rtf([string]$text, [string]$lang, [string]$fontName, [double]$fontSize) {
    $pal = @($C.fg, $C.kw, $C.str, $C.cmt, $C.num, $C.fn, $C.ty)
    $ct = New-Object System.Text.StringBuilder
    [void]$ct.Append('{\colortbl ;')
    for ($i = 0; $i -lt $pal.Count; $i++) {
        $col = $pal[$i]
        [void]$ct.Append("\red$([int]$col.R)\green$([int]$col.G)\blue$([int]$col.B);")
    }
    [void]$ct.Append('}')
    $fs = [int]($fontSize * 2)
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append("{\rtf1\ansi\deff0{\fonttbl{\f0\fnil\fcharset0 $fontName;}}")
    [void]$sb.Append($ct.ToString())
    [void]$sb.Append("\f0\fs$fs\cf1 ")
    $kws = $script:KW[$lang]
    $pos = 0
    foreach ($m in $TOKEN_RE.Matches($text)) {
        if ($m.Index -gt $pos) {
            [void]$sb.Append((Esc-Rtf $text.Substring($pos, $m.Index - $pos)))
        }
        $esc = Esc-Rtf $m.Value
        $ci = 1
        if ($m.Groups['c'].Success) { $ci = 4 }
        elseif ($m.Groups['s'].Success) { $ci = 3 }
        elseif ($m.Groups['n'].Success) { $ci = 5 }
        elseif ($m.Groups['w'].Success) {
            if ($kws -and $kws.Contains($m.Value.ToLower())) { $ci = 2 }
        }
        [void]$sb.Append("\cf$ci $esc")
        $pos = $m.Index + $m.Length
    }
    if ($pos -lt $text.Length) {
        [void]$sb.Append((Esc-Rtf $text.Substring($pos)))
    }
    [void]$sb.Append("\cf1 }")
    return $sb.ToString()
}

$script:LANG = 0
$STR = @{
 file=@('File','Файл','Archivo'); edit=@('Edit','Правка','Edición'); search=@('Search','Поиск','Buscar')
 view=@('View','Вид','Ver'); tools=@('Tools','Инструменты','Herramientas'); lang=@('Language','Язык','Idioma')
 help=@('Help','Справка','Ayuda')
 new=@('New','Создать','Nuevo'); open=@('Open','Открыть','Abrir'); save=@('Save','Сохранить','Guardar')
 saveas=@('Save As','Сохранить как','Guardar como'); print=@('Print','Печать','Imprimir'); exit=@('Exit','Выход','Salir')
 recent=@('Recent','Недавние','Recientes')
 undo=@('Undo','Отменить','Deshacer'); redo=@('Redo','Повторить','Rehacer')
 cut=@('Cut','Вырезать','Cortar'); copy=@('Copy','Копировать','Copiar')
 paste=@('Paste','Вставить','Pegar'); selall=@('Select All','Выделить всё','Seleccionar todo')
 find=@('Find / Replace','Найти / Заменить','Buscar / Reemplazar')
 findnext=@('Find Next','Найти далее','Buscar siguiente'); findprev=@('Find Prev','Найти назад','Buscar anterior')
 goto=@('Go To Line','Перейти к строке','Ir a línea')
 replace=@('Replace','Заменить','Reemplazar'); replaceall=@('Replace All','Заменить всё','Reemplazar todo')
 wrap=@('Word Wrap','Перенос строк','Ajuste de línea'); linenums=@('Line Numbers','Номера строк','Números de línea')
 fullscreen=@('Full Screen','Полный экран','Pantalla completa')
 zoomin=@('Zoom In','Увеличить','Acercar'); zoomout=@('Zoom Out','Уменьшить','Alejar')
 zoomreset=@('Reset Zoom','Сброс масштаба','Restablecer zoom')
 theme=@('Toggle Theme','Сменить тему','Cambiar tema')
 stats=@('Statistics','Статистика','Estadísticas'); hash=@('Hash (MD5/SHA)','Хеш (MD5/SHA)','Hash (MD5/SHA)')
 b64e=@('Base64 Encode','Кодировать Base64','Codificar Base64'); b64d=@('Base64 Decode','Декодировать Base64','Decodificar Base64')
 urlenc=@('URL Encode','Кодировать URL','Codificar URL'); urldec=@('URL Decode','Декодировать URL','Decodificar URL')
 jsonfmt=@('Format JSON','Формат JSON','Formatear JSON'); jsonmin=@('Minify JSON','Минифицировать JSON','Minificar JSON')
 uuid=@('Insert UUID','Вставить UUID','Insertar UUID'); lorem=@('Insert Lorem','Вставить Lorem','Insertar Lorem')
 passgen=@('Password Generator','Генератор паролей','Generador de contraseñas')
 date=@('Insert Date/Time','Вставить дату/время','Insertar fecha/hora')
 casemenu=@('Change Case','Изменить регистр','Cambiar mayúsculas')
 upper=@('UPPERCASE','ВЕРХНИЙ РЕГИСТР','MAYÚSCULAS'); lower=@('lowercase','нижний регистр','minúsculas')
 titlec=@('Title Case','Заголовок','Capitalizar'); invert=@('Invert Case','Инвертировать','Invertir')
 linesmenu=@('Line Operations','Операции со строками','Operaciones de línea')
 sortasc=@('Sort A-Z','Сортировать А-Я','Ordenar A-Z'); sortdesc=@('Sort Z-A','Сортировать Я-А','Ordenar Z-A')
 dedupe=@('Remove Duplicates','Удалить дубликаты','Eliminar duplicados')
 trimws=@('Trim Trailing','Обрезать пробелы','Recortar espacios')
 revlines=@('Reverse Lines','Обратный порядок','Invertir líneas'); shuffle=@('Shuffle','Перемешать','Mezclar')
 numlines=@('Number Lines','Нумеровать строки','Numerar líneas'); rmempty=@('Remove Empty','Удалить пустые','Eliminar vacías')
 palette=@('Command Palette','Командная палитра','Paleta de comandos')
 about=@('About','О программе','Acerca de'); shortcuts=@('Shortcuts','Горячие клавиши','Atajos')
 saved=@('Saved','Сохранено','Guardado'); opened=@('Opened','Открыто','Abierto')
 untitled=@('Untitled','Без имени','Sin título'); copied=@('Copied','Скопировано','Copiado')
 ask_save=@('Save changes?','Сохранить изменения?','¿Guardar cambios?')
 notfound=@('Not found','Не найдено','No encontrado'); replaced=@('Replaced','Заменено','Reemplazado')
 st_title=@('Statistics','Статистика','Estadísticas'); st_chars=@('Characters','Символы','Caracteres')
 st_words=@('Words','Слова','Palabras'); st_lines=@('Lines','Строки','Líneas'); st_read=@('Reading time','Время чтения','Tiempo de lectura')
 pass_title=@('Password Generator','Генератор паролей','Generador de contraseñas')
 pass_len=@('Length','Длина','Longitud'); pal_prompt=@('Command:','Команда:','Comando:')
 hlmenu=@('Syntax','Синтаксис','Sintaxis'); hlplain=@('Plain Text','Обычный','Texto plano')
}
function Tr([string]$k){ return $STR[$k][$script:LANG] }

$S = @{ path=$null; dirty=$false; loading=$false; light=$false; full=$false; findOpen=$false; msg=''; zoom=1.0; lang='plain' }
$script:lastRtfText = ''

$form = New-Object System.Windows.Forms.Form
$form.ClientSize = New-Object System.Drawing.Size(1100,680)
$form.MinimumSize = New-Object System.Drawing.Size(480,320)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'Sizable'
$form.BackColor = $C.bg; $form.ForeColor = $C.fg
$form.Font = New-Object System.Drawing.Font('Segoe UI',9)
$form.KeyPreview = $true; $form.AllowDrop = $true; $form.Opacity = 0

$menu = New-Object System.Windows.Forms.MenuStrip
$menu.BackColor = $C.panel; $menu.ForeColor = $C.fg
$menu.Padding = New-Object System.Windows.Forms.Padding(4,2,0,2)
$form.MainMenuStrip = $menu

$MENU_TEXTS = New-Object System.Collections.ArrayList
function RegMenu { param($it,$key) $it.Text = Tr $key; $it.ForeColor = $C.fg; [void]$MENU_TEXTS.Add(@{c=$it;k=$key}) }
function MTop([string]$key) { $m = New-Object System.Windows.Forms.ToolStripMenuItem; RegMenu $m $key; [void]$menu.Items.Add($m); return $m }
function MItem($parent,[string]$key,[scriptblock]$act=$null,[string]$sc=$null) {
 $it = New-Object System.Windows.Forms.ToolStripMenuItem; RegMenu $it $key
 if ($act) { $it.Add_Click($act) }
 if ($sc) { try { $it.ShortcutKeys = [System.Windows.Forms.Keys]$sc; $it.ShowShortcutKeys = $false } catch { } }
 [void]$parent.DropDownItems.Add($it); return $it
}
function MSep($parent) { [void]$parent.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator)) }

$mFile = MTop 'file'
$recentMenu = New-Object System.Windows.Forms.ToolStripMenuItem; RegMenu $recentMenu 'recent'
[void]$mFile.DropDownItems.Add($recentMenu)
$recentList = New-Object System.Collections.ArrayList
MSep $mFile
[void](MItem $mFile 'new'  { Do-New }  'Ctrl+N')
[void](MItem $mFile 'open' { Do-Open } 'Ctrl+O')
[void](MItem $mFile 'save' { Do-Save } 'Ctrl+S')
[void](MItem $mFile 'saveas' { Do-SaveAs })
MSep $mFile
[void](MItem $mFile 'print' { Do-Print } 'Ctrl+P')
MSep $mFile
[void](MItem $mFile 'exit' { $form.Close() })

$mEdit = MTop 'edit'
[void](MItem $mEdit 'undo' { if ($rtb.CanUndo) { $rtb.Undo() } })
[void](MItem $mEdit 'redo' { if ($rtb.CanRedo) { $rtb.Redo() } })
MSep $mEdit
[void](MItem $mEdit 'cut' { $rtb.Cut() })
[void](MItem $mEdit 'copy' { $rtb.Copy() })
[void](MItem $mEdit 'paste' { if ($rtb.CanPaste([System.Windows.Forms.DataFormats]::Text)) { $rtb.Paste() } })
[void](MItem $mEdit 'selall' { $rtb.SelectAll() })

$mSearch = MTop 'search'
[void](MItem $mSearch 'find' { Toggle-Find } 'Ctrl+F')
[void](MItem $mSearch 'findnext' { Find-Next } 'F3')
[void](MItem $mSearch 'findprev' { Find-Prev })
[void](MItem $mSearch 'goto' { Do-Goto } 'Ctrl+G')

$mView = MTop 'view'
[void](MItem $mView 'wrap' { Set-Wrap (-not $rtb.WordWrap) })
[void](MItem $mView 'linenums' { $gutter.Visible = -not $gutter.Visible; Update-Gutter })
[void](MItem $mView 'fullscreen' { Toggle-Full } 'F11')
MSep $mView
[void](MItem $mView 'zoomin' { Set-Zoom ($S.zoom + 0.1) })
[void](MItem $mView 'zoomout' { Set-Zoom ($S.zoom - 0.1) })
[void](MItem $mView 'zoomreset' { Set-Zoom 1.0 })
MSep $mView
[void](MItem $mView 'theme' { $S.light = -not $S.light; Apply-Theme } 'Ctrl+T')

$mHl = New-Object System.Windows.Forms.ToolStripMenuItem; RegMenu $mHl 'hlmenu'
[void]$mView.DropDownItems.Add($mHl)
$hlChoices = @('plain','js','py','ps','bat','json','sql','cs','cpp','java')
foreach ($lc in $hlChoices) {
    $code = $lc
    $mi = New-Object System.Windows.Forms.ToolStripMenuItem
    $mi.Text = $lc; $mi.ForeColor = $C.fg; $mi.Tag = $lc
    $mi.Add_Click({ $S.lang = [string]$this.Tag; Refresh-Highlight }.GetNewClosure())
    [void]$mHl.DropDownItems.Add($mi)
}

$mTools = MTop 'tools'
[void](MItem $mTools 'stats' { Show-Stats })
[void](MItem $mTools 'hash' { Do-Hash })
MSep $mTools
[void](MItem $mTools 'b64e' { Transform-Text { param($x) [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($x)) } })
[void](MItem $mTools 'b64d' { Transform-Text { param($x) [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($x.Trim())) } })
[void](MItem $mTools 'urlenc' { Transform-Text { param($x) [Uri]::EscapeDataString($x) } })
[void](MItem $mTools 'urldec' { Transform-Text { param($x) [Uri]::UnescapeDataString($x) } })
[void](MItem $mTools 'jsonfmt' { Do-Json $true })
[void](MItem $mTools 'jsonmin' { Do-Json $false })
MSep $mTools
[void](MItem $mTools 'uuid' { $rtb.SelectedText = [guid]::NewGuid().ToString() })
[void](MItem $mTools 'lorem' { $rtb.SelectedText = Get-Lorem })
[void](MItem $mTools 'passgen' { Show-PassGen })
[void](MItem $mTools 'date' { $rtb.SelectedText = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') })
MSep $mTools
$mCase = New-Object System.Windows.Forms.ToolStripMenuItem; RegMenu $mCase 'casemenu'
[void]$mTools.DropDownItems.Add($mCase)
[void](MItem $mCase 'upper' { Transform-Text { param($x) $x.ToUpper() } })
[void](MItem $mCase 'lower' { Transform-Text { param($x) $x.ToLower() } })
[void](MItem $mCase 'titlec' { Transform-Text { param($x) (Get-Culture).TextInfo.ToTitleCase($x.ToLower()) } })
[void](MItem $mCase 'invert' { Transform-Text { param($x) -join ($x.ToCharArray() | ForEach-Object { if ([char]::IsUpper($_)) { [char]::ToLower($_) } elseif ([char]::IsLower($_)) { [char]::ToUpper($_) } else { $_ } }) } })
$mLines = New-Object System.Windows.Forms.ToolStripMenuItem; RegMenu $mLines 'linesmenu'
[void]$mTools.DropDownItems.Add($mLines)
[void](MItem $mLines 'sortasc'  { Line-Op { param($l) $l | Sort-Object } })
[void](MItem $mLines 'sortdesc' { Line-Op { param($l) $l | Sort-Object -Descending } })
[void](MItem $mLines 'dedupe'   { Line-Op { param($l) $l | Select-Object -Unique } })
[void](MItem $mLines 'trimws'   { Line-Op { param($l) $l | ForEach-Object { $_.TrimEnd() } } })
[void](MItem $mLines 'revlines' { Line-Op { param($l) [array]::Reverse($l); $l } })
[void](MItem $mLines 'shuffle'  { Line-Op { param($l) $l | Sort-Object { Get-Random } } })
[void](MItem $mLines 'numlines' { Line-Op { param($l) $i=0; $l | ForEach-Object { $i++; "$i. $_" } } })
[void](MItem $mLines 'rmempty'  { Line-Op { param($l) @($l | Where-Object { $_ -ne '' }) } })

$mLang = MTop 'lang'
$langLabels = @('English','Русский','Español')
for ($i=0; $i -lt 3; $i++) {
 $mi = New-Object System.Windows.Forms.ToolStripMenuItem
 $mi.Text = $langLabels[$i]; $mi.ForeColor = $C.fg; $mi.Tag = $i
 $mi.Add_Click({ $script:LANG = [int]$this.Tag; Apply-Lang })
 [void]$mLang.DropDownItems.Add($mi)
}

$mHelp = MTop 'help'
[void](MItem $mHelp 'palette' { Show-Palette } 'Ctrl+Shift+P')
[void](MItem $mHelp 'shortcuts' { Show-Shortcuts })
[void](MItem $mHelp 'about' { [System.Windows.Forms.MessageBox]::Show("NotePad== 2.5 (RTF highlighting)`nEnglish / Русский / Español", 'About', 'OK', 'Information') })

$findPanel = New-Object System.Windows.Forms.Panel
$findPanel.Dock='Top'; $findPanel.Height=0; $findPanel.BackColor=$C.panel2
$txtFind = New-Object System.Windows.Forms.TextBox
$txtFind.Location=New-Object System.Drawing.Point(10,8); $txtFind.Size=New-Object System.Drawing.Size(220,24)
$txtFind.BorderStyle='FixedSingle'; $txtFind.BackColor=$C.field; $txtFind.ForeColor=$C.fg
$txtRep = New-Object System.Windows.Forms.TextBox
$txtRep.Location=New-Object System.Drawing.Point(240,8); $txtRep.Size=New-Object System.Drawing.Size(220,24)
$txtRep.BorderStyle='FixedSingle'; $txtRep.BackColor=$C.field; $txtRep.ForeColor=$C.fg
$findPanel.Controls.Add($txtFind); $findPanel.Controls.Add($txtRep)

function Find-Btn([string]$key,[int]$x,[scriptblock]$act,[int]$w=86) {
 $b = New-Object System.Windows.Forms.Button
 $b.Text = Tr $key
 $b.Location = New-Object System.Drawing.Point($x,7); $b.Size = New-Object System.Drawing.Size($w,26)
 $b.FlatStyle = 'Flat'; $b.BackColor = $C.panel; $b.ForeColor = $C.fg
 $b.FlatAppearance.BorderColor = $C.border
 $b.Add_Click($act); $b.Tag = $key
 [void]$findPanel.Controls.Add($b)
 [void]$MENU_TEXTS.Add(@{c=$b;k=$key})
}
Find-Btn 'findnext' 470 { Find-Next }
Find-Btn 'replace' 560 { Do-Replace }
Find-Btn 'replaceall' 650 { Do-ReplaceAll } 100
$btnX = New-Object System.Windows.Forms.Button
$btnX.Text='X'; $btnX.Location=New-Object System.Drawing.Point(756,7); $btnX.Size=New-Object System.Drawing.Size(30,26)
$btnX.FlatStyle='Flat'; $btnX.BackColor=$C.panel; $btnX.ForeColor=$C.fg
$btnX.FlatAppearance.BorderColor=$C.border
$btnX.Add_Click({ Toggle-Find })
$findPanel.Controls.Add($btnX)

$tbScroll = New-Object System.Windows.Forms.Panel
$tbScroll.Dock='Top'; $tbScroll.Height=40; $tbScroll.BackColor=$C.panel
$tbScroll.AutoScroll = $true
$tb = New-Object System.Windows.Forms.FlowLayoutPanel
$tb.AutoSize = $true
$tb.AutoSizeMode = 'GrowAndShrink'
$tb.Location = New-Object System.Drawing.Point(0,0)
$tb.BackColor = $C.panel
$tb.Padding = New-Object System.Windows.Forms.Padding(4,5,4,5)
$tb.WrapContents = $false
$tbScroll.Controls.Add($tb)

$ALL_BTNS = New-Object System.Collections.ArrayList
function Add-TB([string]$key,[scriptblock]$act,[int]$w=0) {
 $txt = Tr $key
 if ($w -le 0) { $w = [Math]::Max(38, ($txt.Length * 8) + 18) }
 $b = New-Object System.Windows.Forms.Label
 $b.Text = $txt; $b.Size = New-Object System.Drawing.Size($w,26)
 $b.TextAlign='MiddleCenter'; $b.BackColor=$C.panel; $b.ForeColor=$C.fg
 $b.Cursor=[System.Windows.Forms.Cursors]::Hand
 $b.Margin = New-Object System.Windows.Forms.Padding(1,0,1,0)
 $b.Add_Click($act)
 $tm = New-Object System.Windows.Forms.Timer; $tm.Interval = 20
 $b.Tag = @{ timer=$tm; t=0.0; target=0.0; n=$C.panel; h=$C.hover; key=$key }
 $tm.Tag = $b
 $tm.Add_Tick({
   $lbl = $this.Tag; $st = $lbl.Tag
   if ($st.t -lt $st.target) { $st.t = [Math]::Min(1.0, $st.t + 0.14) }
   elseif ($st.t -gt $st.target) { $st.t = [Math]::Max(0.0, $st.t - 0.14) }
   else { $this.Stop(); return }
   $n=$st.n; $hv=$st.h
   $lbl.BackColor = [System.Drawing.Color]::FromArgb(
     [int]($n.R + ($hv.R - $n.R) * $st.t),
     [int]($n.G + ($hv.G - $n.G) * $st.t),
     [int]($n.B + ($hv.B - $n.B) * $st.t))
 })
 $b.Add_MouseEnter({ $st = $this.Tag; $st.target = 1.0; $st.timer.Start() })
 $b.Add_MouseLeave({ $st = $this.Tag; $st.target = 0.0; $st.timer.Start() })
 [void]$tb.Controls.Add($b)
 [void]$ALL_BTNS.Add(@{lbl=$b; key=$key})
}
function TSep { $p = New-Object System.Windows.Forms.Panel; $p.Size=New-Object System.Drawing.Size(1,20); $p.BackColor=$C.border; $p.Margin=New-Object System.Windows.Forms.Padding(5,3,5,3); [void]$tb.Controls.Add($p) }

Add-TB 'new' { Do-New }
Add-TB 'open' { Do-Open }
Add-TB 'save' { Do-Save }
TSep
Add-TB 'undo' { if ($rtb.CanUndo) { $rtb.Undo() } }
Add-TB 'redo' { if ($rtb.CanRedo) { $rtb.Redo() } }
TSep
Add-TB 'find' { Toggle-Find }
Add-TB 'goto' { Do-Goto }
TSep
Add-TB 'stats' { Show-Stats }
Add-TB 'hash'  { Do-Hash }
Add-TB 'date'  { $rtb.SelectedText = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'); Refresh-Highlight }
TSep
Add-TB 'zoomin' { Set-Zoom ($S.zoom + 0.1) }
Add-TB 'zoomout' { Set-Zoom ($S.zoom - 0.1) }
Add-TB 'wrap' { Set-Wrap (-not $rtb.WordWrap) }
Add-TB 'theme' { $S.light = -not $S.light; Apply-Theme }
Add-TB 'fullscreen' { Toggle-Full }

$host2 = New-Object System.Windows.Forms.Panel
$host2.Dock='Fill'; $host2.BackColor=$C.edit

$editorFont = New-Object System.Drawing.Font('Consolas', 11.5)
$script:baseFontSize = 11.5

$rtb = New-Object System.Windows.Forms.RichTextBox
$rtb.Dock='Fill'; $rtb.BorderStyle='None'
$rtb.BackColor=$C.edit; $rtb.ForeColor=$C.fg
$rtb.Font = $editorFont
$rtb.WordWrap=$false; $rtb.AcceptsTab=$true; $rtb.DetectUrls=$false
$rtb.HideSelection=$false; $rtb.AllowDrop=$true; $rtb.ScrollBars='Both'
$rtb.EnableAutoDragDrop = $false
$rtb.ShortcutsEnabled = $true

$gutter = New-Object System.Windows.Forms.Panel
$gutter.Dock='Left'; $gutter.Width=54; $gutter.BackColor=$C.gutter
$gutter.Font = New-Object System.Drawing.Font($editorFont.FontFamily, [Math]::Max(6, $editorFont.Size - 1.5))
$host2.Controls.Add($gutter); $host2.Controls.Add($rtb); $rtb.BringToFront()

$status = New-Object System.Windows.Forms.Panel
$status.Dock='Bottom'; $status.Height=24; $status.BackColor=$C.panel
function New-StatusLabel {
  $l = New-Object System.Windows.Forms.Label
  $l.AutoSize=$true; $l.TextAlign='MiddleLeft'
  $l.ForeColor=$C.dim; $l.Font=New-Object System.Drawing.Font('Segoe UI',8.5)
  $l.Padding=New-Object System.Windows.Forms.Padding(8,0,8,0); $l.Height=24
  return $l
}
$lblInfo = New-StatusLabel; $lblMsg = New-StatusLabel; $lblPos = New-StatusLabel
$lblZoom = New-StatusLabel; $lblEnc = New-StatusLabel; $lblLang = New-StatusLabel
$lblMsg.ForeColor = $C.accent
$lblEnc.Text = 'UTF-8'
$lblInfo.Dock='Left'; $lblMsg.Dock='Left'; $lblLang.Dock='Left'
$lblEnc.Dock='Right'; $lblZoom.Dock='Right'; $lblPos.Dock='Right'
foreach ($lbl in @($lblInfo,$lblMsg,$lblLang,$lblEnc,$lblZoom,$lblPos)) { $status.Controls.Add($lbl) }

$form.Controls.Add($host2)
$form.Controls.Add($findPanel)
$form.Controls.Add($tbScroll)
$form.Controls.Add($status)
$form.Controls.Add($menu)

function Set-EditorContent([string]$text) {
    $S.loading = $true
    try {
        $rtf = Build-Rtf $text $S.lang $rtb.Font.Name $rtb.Font.Size
        $rtb.Rtf = $rtf
        $script:lastRtfText = $text
        $rtb.SelectionStart = 0
        $rtb.SelectionLength = 0
    } catch {
        $rtb.Clear()
        $rtb.SelectionColor = $C.fg
        $rtb.SelectionFont = $rtb.Font
        $rtb.SelectedText = $text
    }
    $S.loading = $false
}

function Refresh-Highlight {
    $cur = $rtb.Text
    $selStart = $rtb.SelectionStart
    $selLen = $rtb.SelectionLength
    Set-EditorContent $cur
    try { $rtb.Select([Math]::Min($selStart, $rtb.TextLength), [Math]::Min($selLen, [Math]::Max(0, $rtb.TextLength - $selStart))) } catch { }
    Update-Gutter; Update-Status
}

function Apply-Theme {
 if ($S.light) { SetLight } else { SetDark }
 $form.BackColor=$C.bg; $form.ForeColor=$C.fg
 $menu.BackColor=$C.panel; $menu.ForeColor=$C.fg
 try {
   if ($S.light) { $menu.Renderer = New-Object FlatRend -ArgumentList @((New-Object FlatTable -ArgumentList @($C.bg,$C.hover,$C.border)), $C.fg, $C.bg, $C.hover) }
   else         { $menu.Renderer = New-Object FlatRend -ArgumentList @((New-Object FlatTable -ArgumentList @($C.panel,$C.hover,$C.border)), $C.fg, $C.panel, $C.hover) }
 } catch { }
 $tbScroll.BackColor=$C.panel
 $tb.BackColor=$C.panel; $status.BackColor=$C.panel; $findPanel.BackColor=$C.panel2
 $host2.BackColor=$C.edit
 $gutter.BackColor=$C.gutter
 $txtFind.BackColor=$C.field; $txtFind.ForeColor=$C.fg
 $txtRep.BackColor=$C.field; $txtRep.ForeColor=$C.fg
 foreach ($lbl in @($lblInfo,$lblMsg,$lblLang,$lblEnc,$lblZoom,$lblPos)) { $lbl.BackColor=$C.panel; $lbl.ForeColor=$C.dim }
 $lblMsg.ForeColor=$C.accent
 foreach ($btn in $ALL_BTNS) {
   $btn.lbl.BackColor = $C.panel; $btn.lbl.ForeColor = $C.fg
   $btn.lbl.Tag.n = $C.panel; $btn.lbl.Tag.h = $C.hover; $btn.lbl.Tag.t = 0.0
 }
 foreach ($tex in $MENU_TEXTS) { $tex.c.ForeColor = $C.fg }
 foreach ($ctrl in $findPanel.Controls) {
   if ($ctrl -is [System.Windows.Forms.Button]) {
     $ctrl.BackColor = $C.panel; $ctrl.ForeColor = $C.fg
     $ctrl.FlatAppearance.BorderColor = $C.border
   }
 }
 Refresh-Highlight
 $gutter.Invalidate()
}
function Apply-Lang {
 foreach ($tex in $MENU_TEXTS) { $tex.c.Text = Tr $tex.k }
 foreach ($btn in $ALL_BTNS) { $btn.lbl.Text = Tr $btn.key; $btn.lbl.Width = [Math]::Max(38, ($btn.lbl.Text.Length*8)+18) }
 Update-Title; Update-Status
}

function Update-Title {
 $n = Tr 'untitled'; if ($S.path) { $n = [System.IO.Path]::GetFileName($S.path) }
 $m = if ($S.dirty) { '*' } else { '' }
 $form.Text = "$m$n - NotePad=="
}
function Update-Gutter {
 $last = $rtb.GetLineFromCharIndex($rtb.TextLength) + 1
 $d = [Math]::Max(2, "$last".Length)
 $w = [int]($rtb.Font.Size * 0.78 * $d + 20)
 if ($w -lt 44) { $w = 44 }; if ($w -gt 140) { $w = 140 }
 $gutter.Width = $w; $gutter.Invalidate()
}
function Update-Status {
 try {
   $i = $rtb.SelectionStart
   $ln = $rtb.GetLineFromCharIndex($i)
   $fs = $rtb.GetFirstCharIndexFromLine($ln); if ($fs -lt 0) { $fs = 0 }
   if ($lblPos)  { $lblPos.Text  = "Ln $($ln+1), Col $($i - $fs + 1)" }
   if ($lblInfo) { $lblInfo.Text = "$($rtb.TextLength) / $($rtb.Lines.Count)" }
   if ($lblZoom) { $lblZoom.Text = "$([int]($S.zoom*100))%" }
   if ($lblMsg)  { $lblMsg.Text  = $S.msg }
   if ($lblLang) { $lblLang.Text = " • $($S.lang)" }
 } catch { }
}
$msgTimer = New-Object System.Windows.Forms.Timer; $msgTimer.Interval = 1800
$msgTimer.Add_Tick({ $S.msg=''; Update-Status; $this.Stop() })
function Flash([string]$txt) { $S.msg = $txt; Update-Status; $msgTimer.Stop(); $msgTimer.Start() }

function Set-Wrap([bool]$on) {
 $rtb.WordWrap = $on
 if ($on) { $rtb.ScrollBars='Vertical' } else { $rtb.ScrollBars='Both' }
 Update-Gutter
}
function Set-Zoom([double]$z) {
 if ($z -lt 0.2) { $z = 0.2 }; if ($z -gt 5.0) { $z = 5.0 }
 $S.zoom = $z
 $newSize = [Math]::Max(4, [Math]::Min(72, $script:baseFontSize * $z))
 $fam = $rtb.Font.FontFamily
 $rtb.Font = New-Object System.Drawing.Font($fam, $newSize)
 $gutter.Font = New-Object System.Drawing.Font($fam, [Math]::Max(6, $newSize - 1.5))
 Refresh-Highlight
}
function Toggle-Full {
 $S.full = -not $S.full
 if ($S.full) {
   $form.FormBorderStyle='None'; $form.WindowState='Maximized'
   $menu.Visible=$false; $tbScroll.Visible=$false; $status.Visible=$false; $findPanel.Visible=$false
 } else {
   $form.FormBorderStyle='Sizable'; $form.WindowState='Normal'
   $menu.Visible=$true; $tbScroll.Visible=$true; $status.Visible=$true; $findPanel.Visible=$true
 }
}

function Add-Recent([string]$p) {
 $i = $recentList.IndexOf($p); if ($i -ge 0) { $recentList.RemoveAt($i) }
 $recentList.Insert(0,$p)
 while ($recentList.Count -gt 10) { $recentList.RemoveAt($recentList.Count-1) }
 $recentMenu.DropDownItems.Clear()
 foreach ($r in $recentList) {
   $rr = $r
   $mi = New-Object System.Windows.Forms.ToolStripMenuItem
   $mi.Text = [System.IO.Path]::GetFileName($r); $mi.ForeColor = $C.fg
   $mi.Add_Click({ Load-File $rr }.GetNewClosure())
   [void]$recentMenu.DropDownItems.Add($mi)
 }
}
function Load-File([string]$p) {
 if (-not $p -or -not (Test-Path -LiteralPath $p)) { return }
 try {
   $raw = [System.IO.File]::ReadAllText($p)
   $S.lang = Get-LangFromExt $p
   Set-EditorContent $raw
   $S.path = (Resolve-Path -LiteralPath $p).Path
   $S.dirty = $false
   Add-Recent $S.path
   Update-Title; Update-Gutter; Update-Status
   Flash "$(Tr 'opened'): $([System.IO.Path]::GetFileName($p))"
 } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'NotePad==','OK','Error') }
}
function Do-New {
 if ($S.dirty) {
   $r = [System.Windows.Forms.MessageBox]::Show((Tr 'ask_save'),'NotePad==','YesNoCancel','Question')
   if ($r -eq 'Cancel') { return }
   if ($r -eq 'Yes') { Do-Save; if ($S.dirty) { return } }
 }
 Set-EditorContent ''
 $S.path = $null; $S.dirty = $false
 Update-Title; Update-Gutter; Update-Status
}
function Do-Open {
 $ofd = New-Object System.Windows.Forms.OpenFileDialog
 $ofd.Filter = 'All files (*.*)|*.*|Text (*.txt)|*.txt|Batch (*.bat;*.cmd)|*.bat;*.cmd|PowerShell (*.ps1)|*.ps1|Log (*.log)|*.log|Markdown (*.md)|*.md|JSON (*.json)|*.json|Code (*.js;*.ts;*.py;*.cs;*.cpp;*.java)|*.js;*.ts;*.py;*.cs;*.cpp;*.java'
 if ($ofd.ShowDialog() -eq 'OK') { Load-File $ofd.FileName }
}
function Do-Save {
 if (-not $S.path) { Do-SaveAs; return }
 try {
   [System.IO.File]::WriteAllText($S.path, $rtb.Text, (New-Object System.Text.UTF8Encoding($false)))
   $S.dirty = $false; Update-Title; Flash (Tr 'saved')
 } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'NotePad==','OK','Error') }
}
function Do-SaveAs {
 $sfd = New-Object System.Windows.Forms.SaveFileDialog
 $sfd.Filter='Text (*.txt)|*.txt|All files (*.*)|*.*|Batch (*.bat)|*.bat|PowerShell (*.ps1)|*.ps1|JSON (*.json)|*.json|Markdown (*.md)|*.md'
 if ($S.path) { $sfd.FileName = [System.IO.Path]::GetFileName($S.path) }
 if ($sfd.ShowDialog() -eq 'OK') {
     $S.path = $sfd.FileName
     $S.lang = Get-LangFromExt $S.path
     Do-Save
     Refresh-Highlight
 }
}
function Do-Print {
 $pd = New-Object System.Drawing.Printing.PrintDocument
 $text = $rtb.Text
 $pd.Add_PrintPage({ param($sndr,$ev) $f = New-Object System.Drawing.Font('Consolas',10); $ev.Graphics.DrawString($text,$f,[System.Drawing.Brushes]::Black,$ev.MarginBounds) }.GetNewClosure())
 $dlg = New-Object System.Windows.Forms.PrintDialog; $dlg.Document = $pd
 if ($dlg.ShowDialog() -eq 'OK') { $pd.Print() }
}

function Toggle-Find {
 $S.findOpen = -not $S.findOpen
 $findTimer.Start()
 if ($S.findOpen) { $txtFind.Focus(); $txtFind.SelectAll() }
}
function Find-Next {
 $q = $txtFind.Text; if ($q -eq '') { return }
 $start = $rtb.SelectionStart + $rtb.SelectionLength
 if ($start -ge $rtb.TextLength) { $start = 0 }
 $idx = $rtb.Find($q, $start, [System.Windows.Forms.RichTextBoxFinds]::None)
 if ($idx -lt 0 -and $start -gt 0) { $idx = $rtb.Find($q, 0, [System.Windows.Forms.RichTextBoxFinds]::None) }
 if ($idx -lt 0) { Flash (Tr 'notfound') }
 else { $rtb.Select($idx, $q.Length); $rtb.ScrollToCaret(); $rtb.Focus() }
}
function Find-Prev {
 $q = $txtFind.Text; if ($q -eq '') { return }
 $start = [Math]::Max(0, $rtb.SelectionStart - 1)
 $idx = $rtb.Find($q, 0, $start, [System.Windows.Forms.RichTextBoxFinds]::Reverse)
 if ($idx -lt 0) { $idx = $rtb.Find($q, $start, [System.Windows.Forms.RichTextBoxFinds]::Reverse) }
 if ($idx -lt 0) { Flash (Tr 'notfound') }
 else { $rtb.Select($idx, $q.Length); $rtb.ScrollToCaret(); $rtb.Focus() }
}
function Do-Replace {
 $q = $txtFind.Text; if ($q -eq '') { return }
 if ($rtb.SelectedText -eq $q) { $rtb.SelectedText = $txtRep.Text }
 Find-Next
}
function Do-ReplaceAll {
 $q = $txtFind.Text; if ($q -eq '') { return }
 $c = ([regex]::Matches($rtb.Text, [regex]::Escape($q))).Count
 if ($c -gt 0) {
     $txt = $rtb.Text.Replace($q, $txtRep.Text)
     Set-EditorContent $txt
     Flash "$(Tr 'replaced'): $c"
 } else { Flash (Tr 'notfound') }
 Update-Gutter; Update-Status
}
$findTimer = New-Object System.Windows.Forms.Timer; $findTimer.Interval = 12
$findTimer.Add_Tick({
 $target = if ($S.findOpen) { 42 } else { 0 }
 $h = $findPanel.Height
 if ($h -eq $target) { $this.Stop(); return }
 $step = 7
 if ($h -lt $target) { $h += $step; if ($h -gt $target) { $h = $target } }
 else { $h -= $step; if ($h -lt $target) { $h = $target } }
 $findPanel.Height = $h
})

function Transform-Text { param([scriptblock]$fn)
 $sel = $rtb.SelectedText
 if ($sel -eq '') { return }
 try { $rtb.SelectedText = & $fn $sel; $rtb.SelectionColor = $C.fg } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'NotePad==','OK','Error') }
}
function Line-Op { param([scriptblock]$fn)
 $lines = $rtb.Text -split "`r?`n"
 $res = @(& $fn $lines)
 Set-EditorContent ($res -join "`r`n")
 Update-Gutter; Update-Status
}
function Do-Goto {
 $v = [Microsoft.VisualBasic.Interaction]::InputBox('Line:','Go To Line','1')
 if ($v -eq '') { return }
 $n = 0; if (-not [int]::TryParse($v, [ref]$n)) { return }
 $max = $rtb.GetLineFromCharIndex($rtb.TextLength)
 if ($n -lt 1) { $n = 1 }; if ($n -gt $max+1) { $n = $max+1 }
 $ci = $rtb.GetFirstCharIndexFromLine($n-1); if ($ci -lt 0) { $ci = $rtb.TextLength }
 $rtb.SelectionStart = $ci; $rtb.SelectionLength = 0; $rtb.ScrollToCaret(); $rtb.Focus()
}
function Show-Stats {
 $txt = $rtb.Text; $ch = $txt.Length
 $words = if ($txt.Trim() -eq '') { 0 } else { ($txt -split '\s+').Count }
 $lines = $rtb.Lines.Count
 $readmin = [Math]::Ceiling($words / 200)
 $msg = "$(Tr 'st_title')`n`n$(Tr 'st_chars'): $ch`n$(Tr 'st_words'): $words`n$(Tr 'st_lines'): $lines`n$(Tr 'st_read'): $readmin min"
 [System.Windows.Forms.MessageBox]::Show($msg,'NotePad==','OK','Information')
}
function Do-Hash {
 $txt = $rtb.SelectedText; if ($txt -eq '') { $txt = $rtb.Text }
 $bb = [Text.Encoding]::UTF8.GetBytes($txt)
 function Hx($arr) { -join ($arr | ForEach-Object { $_.ToString('x2') }) }
 $md5    = (New-Object System.Security.Cryptography.MD5CryptoServiceProvider).ComputeHash($bb)
 $sha1   = (New-Object System.Security.Cryptography.SHA1CryptoServiceProvider).ComputeHash($bb)
 $sha256 = (New-Object System.Security.Cryptography.SHA256CryptoServiceProvider).ComputeHash($bb)
 $msg = "MD5:`n$(Hx $md5)`n`nSHA1:`n$(Hx $sha1)`n`nSHA256:`n$(Hx $sha256)"
 [System.Windows.Forms.Clipboard]::SetText($msg)
 [System.Windows.Forms.MessageBox]::Show($msg + "`n`n$(Tr 'copied')",'Hash','OK','Information')
}
function Do-Json { param([bool]$pretty)
 $txt = $rtb.SelectedText; if ($txt -eq '') { $txt = $rtb.Text }
 try {
   $o = $txt | ConvertFrom-Json
   $r = if ($pretty) { $o | ConvertTo-Json -Depth 100 } else { $o | ConvertTo-Json -Depth 100 -Compress }
   if ($rtb.SelectedText -eq '') { Set-EditorContent $r; $S.lang = 'json' } else { $rtb.SelectedText = $r }
   Refresh-Highlight
 } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'JSON','OK','Error') }
}
function Get-Lorem {
 $w = 'lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua'.Split(' ')
 $out = @(); for ($i=0; $i -lt 50; $i++) { $out += $w[(Get-Random -Min 0 -Max $w.Length)] }
 $s = ($out -join ' ') + '.'
 $s.Substring(0,1).ToUpper() + $s.Substring(1)
}
function Show-PassGen {
 $len = [Microsoft.VisualBasic.Interaction]::InputBox((Tr 'pass_len'),(Tr 'pass_title'),'20')
 $n = 20; if (-not [int]::TryParse($len,[ref]$n) -or $n -lt 4) { $n = 20 }
 $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+'
 $p = -join (1..$n | ForEach-Object { $chars[(Get-Random -Max $chars.Length)] })
 [System.Windows.Forms.Clipboard]::SetText($p)
 [System.Windows.Forms.MessageBox]::Show("$p`n`n$(Tr 'copied')",(Tr 'pass_title'),'OK','Information')
}
function Show-Shortcuts {
 $s = "Ctrl+N/O/S  New/Open/Save`nCtrl+Shift+S  Save As`nCtrl+F  Find/Replace`nF3 / Shift+F3  Next/Prev`nCtrl+G  Go to line`nCtrl+T  Theme`nF11  Fullscreen`nF5  Date/Time`nCtrl+Shift+P  Command palette"
 [System.Windows.Forms.MessageBox]::Show($s,'Shortcuts','OK','Information')
}
function Show-Palette {
 $cmd = [Microsoft.VisualBasic.Interaction]::InputBox((Tr 'pal_prompt'),'NotePad==','')
 if ($cmd -eq '') { return }
 switch -Regex ($cmd.ToLower().Trim()) {
   '^new$'      { Do-New }
   '^open$'     { Do-Open }
   '^save$'     { Do-Save }
   '^wrap$'     { Set-Wrap (-not $rtb.WordWrap) }
   '^theme$'    { $S.light = -not $S.light; Apply-Theme }
   '^full$'     { Toggle-Full }
   '^hash$'     { Do-Hash }
   '^stats$'    { Show-Stats }
   '^upper$'    { Transform-Text { param($x) $x.ToUpper() } }
   '^lower$'    { Transform-Text { param($x) $x.ToLower() } }
   '^sort$'     { Line-Op { param($l) $l | Sort-Object } }
   '^dedupe$'   { Line-Op { param($l) $l | Select-Object -Unique } }
   '^date$'     { $rtb.SelectedText = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'); Refresh-Highlight }
   '^uuid$'     { $rtb.SelectedText = [guid]::NewGuid().ToString() }
   '^lorem$'    { $rtb.SelectedText = Get-Lorem }
   '^(js|py|ps|bat|json|sql|cs|cpp|java|plain)$' { $S.lang = $matches[1]; Refresh-Highlight }
   '^(en|english)$' { $script:LANG = 0; Apply-Lang }
   '^(ru|russian)$' { $script:LANG = 1; Apply-Lang }
   '^(es|spanish)$' { $script:LANG = 2; Apply-Lang }
   default { Flash "Unknown: $cmd" }
 }
}

$gutter.Add_Paint({
 param($sender,$e)
 $g = $e.Graphics; $g.Clear($C.gutter)
 if ($gutter.Width -le 2) { return }
 $f = $sender.Font
 $br = New-Object System.Drawing.SolidBrush($C.gutterfg)
 $p1 = New-Object System.Drawing.Point(1,1)
 $p2 = New-Object System.Drawing.Point(1, [Math]::Max(1, $rtb.ClientSize.Height - 2))
 $c1 = $rtb.GetCharIndexFromPosition($p1); $c2 = $rtb.GetCharIndexFromPosition($p2)
 $l1 = $rtb.GetLineFromCharIndex($c1); $l2 = $rtb.GetLineFromCharIndex($c2)
 if ($l2 -lt $l1) { $l2 = $l1 }
 $sf = New-Object System.Drawing.StringFormat
 $sf.Alignment = [System.Drawing.StringAlignment]::Far
 $rw = $sender.Width - 8
 for ($i = $l1; $i -le $l2; $i++) {
   $ci = $rtb.GetFirstCharIndexFromLine($i); if ($ci -lt 0) { continue }
   $pt = $rtb.GetPositionFromCharIndex($ci)
   $r = New-Object System.Drawing.RectangleF(0, [single]$pt.Y, [single]$rw, [single]($f.GetHeight()+2))
   $g.DrawString("$($i+1)", $f, $br, $r, $sf)
 }
 $br.Dispose()
})

$hlTimer = New-Object System.Windows.Forms.Timer
$hlTimer.Interval = 450
$hlTimer.Add_Tick({
    $hlTimer.Stop()
    if ($S.loading) { return }
    $cur = $rtb.Text
    if ($cur -eq $script:lastRtfText) { return }
    Refresh-Highlight
})

$rtb.Add_TextChanged({
 if (-not $S.loading -and -not $S.dirty) { $S.dirty = $true; Update-Title }
 Update-Gutter
 if (-not $S.loading) { $hlTimer.Stop(); $hlTimer.Start() }
})
$rtb.Add_SelectionChanged({ Update-Status })
$rtb.Add_VScroll({ $gutter.Invalidate() })
$rtb.Add_HScroll({ $gutter.Invalidate() })
$rtb.Add_Resize({ $gutter.Invalidate(); Update-Gutter })
$rtb.Add_FontChanged({ $gutter.Invalidate() })
$form.Add_Resize({ $gutter.Invalidate() })
$form.Add_DragEnter({ param($sndr,$ev) if ($ev.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) { $ev.Effect = 'Copy' } })
$rtb.Add_DragEnter({ param($sndr,$ev) if ($ev.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) { $ev.Effect = 'Copy' } })
$form.Add_DragDrop({ param($sndr,$ev) $ff = $ev.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop); if ($ff -and $ff.Count -gt 0) { Load-File $ff[0] } })
$rtb.Add_DragDrop({ param($sndr,$ev) $ff = $ev.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop); if ($ff -and $ff.Count -gt 0) { Load-File $ff[0] } })

$form.Add_KeyDown({
 param($sndr,$ev)
 $k = $ev.KeyCode.ToString()
 if ($ev.Control -and $ev.Shift) {
   switch ($k) {
     'S' { Do-SaveAs; $ev.SuppressKeyPress=$true; return }
     'P' { Show-Palette; $ev.SuppressKeyPress=$true; return }
     'I' { Show-Stats; $ev.SuppressKeyPress=$true; return }
     'H' { Do-Hash; $ev.SuppressKeyPress=$true; return }
     'F' { Toggle-Find; $ev.SuppressKeyPress=$true; return }
   }
 }
 if ($ev.Control) {
   switch ($k) {
     'N' { Do-New;  $ev.SuppressKeyPress=$true; return }
     'O' { Do-Open; $ev.SuppressKeyPress=$true; return }
     'S' { Do-Save; $ev.SuppressKeyPress=$true; return }
     'F' { Toggle-Find; $ev.SuppressKeyPress=$true; return }
     'H' { Toggle-Find; $ev.SuppressKeyPress=$true; return }
     'G' { Do-Goto; $ev.SuppressKeyPress=$true; return }
     'T' { $S.light = -not $S.light; Apply-Theme; $ev.SuppressKeyPress=$true; return }
     'P' { Do-Print; $ev.SuppressKeyPress=$true; return }
     'A' { $rtb.SelectAll(); $ev.SuppressKeyPress=$true; return }
     'D0' { Set-Zoom 1.0; $ev.SuppressKeyPress=$true; return }
     'Add' { Set-Zoom ($S.zoom + 0.1); $ev.SuppressKeyPress=$true; return }
     'Subtract' { Set-Zoom ($S.zoom - 0.1); $ev.SuppressKeyPress=$true; return }
   }
 }
 switch ($k) {
   'F3'  { if ($ev.Shift) { Find-Prev } else { Find-Next }; $ev.SuppressKeyPress=$true; return }
   'F5'  { $rtb.SelectedText = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'); Refresh-Highlight; $ev.SuppressKeyPress=$true; return }
   'F11' { Toggle-Full; $ev.SuppressKeyPress=$true; return }
   'Escape' { if ($S.findOpen) { Toggle-Find; $ev.SuppressKeyPress=$true; return } }
 }
})
$txtFind.Add_KeyDown({ if ($_.KeyCode -eq 'Enter') { Find-Next; $_.SuppressKeyPress=$true }; if ($_.KeyCode -eq 'Escape') { Toggle-Find; $_.SuppressKeyPress=$true } })
$txtRep.Add_KeyDown({ if ($_.KeyCode -eq 'Enter') { Do-Replace; $_.SuppressKeyPress=$true }; if ($_.KeyCode -eq 'Escape') { Toggle-Find; $_.SuppressKeyPress=$true } })
$form.Add_FormClosing({
 param($sndr,$ev)
 if ($S.dirty) {
   $r = [System.Windows.Forms.MessageBox]::Show((Tr 'ask_save'),'NotePad==','YesNoCancel','Question')
   if ($r -eq 'Cancel') { $ev.Cancel=$true }
   elseif ($r -eq 'Yes') { Do-Save; if ($S.dirty) { $ev.Cancel=$true } }
 }
})

$fade = New-Object System.Windows.Forms.Timer; $fade.Interval = 15
$fade.Add_Tick({ if ($form.Opacity -ge 1.0) { $form.Opacity = 1.0; $this.Stop(); return }
  $v = $form.Opacity + 0.09; if ($v -gt 1) { $v = 1 }; $form.Opacity = $v })

$form.Add_Shown({
 Apply-Theme
 Update-Title; Update-Gutter; Update-Status
 $fade.Start()
 if ($env:FILE -and $env:FILE.Trim() -ne '') { Load-File $env:FILE }
 $rtb.Focus()
})

[void]$form.ShowDialog()