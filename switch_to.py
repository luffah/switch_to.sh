#!/usr/bin/env python3
# Switch_to.py
# --
# Simple script that allows to jump to between named windows
# --
# by luffah <contact@luffah.xyz>
# --
# Licensed under GPLv3.
# Free as in freedom.
# Free to use. Free to share. Free to modify. Free to verify.
import os
import sys
import time
import tty
import re
import subprocess
from datetime import datetime
from optparse import OptionParser
from ewmh import EWMH
from Xlib import X, Xatom

logfile = sys.stderr
DEBUG = os.environ.get('DEBUG', False)
# If you need constant debugging:
# logfile = open('/tmp/switch_to.log', 'a')
# print('-' * 40, file=logfile)
# DEBUG = True

_term_groups = [
    ('st', (['st', 'stterm'],
            ["-t", "{0}", "-c", "{0}"])),
    ('mate', (['lxterminal', 'mate-terminal', 'mate-terminal.wrapper',
               'sakura'],
              ["-t", "{0}"])),
    ('*', (['xterm', 'rxvt', 'xfce4-terminal', 'lxterm', 'koi8rxterm', 'mlterm',
            'uxterm', 'xfce4-terminal.wrapper', 'terminator'],
           ["-T", "{0}"]))
]
default_termname = os.environ.get('SWITCH_TO_TERM_CHAR', '#') + '%s'


def _exec(oscmd):
    return os.popen(oscmd).read().strip()


def logthis(txt, *args):
    if DEBUG:
        print("{0} {1}".format(
            datetime.now(), txt.format(*args)), file=logfile)


class Colors():
    cache_tput = {}
    _color_tab = {
        'rs': [ 'sgr0', ],
        'bold': [ 'bold', ],
        'rev': [ 'bold', 'rev'],
        'title': [ 'bold', 'smul'],
        'grt': [ 'setaf 2', 'bold', 'smul' ],
        'gre': [ 'setaf 2', 'bold', 'rmul' ],
        'mag': [ 'setaf 5', ],
        'yel': [ 'setaf 3', ],
        'yol': [ 'setaf 6', ],
    }
    cumul = []

    def __init__(self, opt):
        self.with_colors = opt.with_colors

    def get(self, name):
        if not self.with_colors:
            return ""
        colors = self._color_tab.get(name, [])
        if 'sgr0' in colors:
            self.cumul = []
            newcolors = colors
        else:
            newcolors = ['sgr0'] + self.cumul + colors
            self.cumul += [c for c in colors
                           if c not in ['bold', 'smul', 'rmul', 'sgr0']
                           or name == 'rev']

        for o in newcolors:
            if o not in self.cache_tput:
                self.cache_tput[o] = _exec('tput ' + o)

        # print(self.cumul)
        # print(newcolors)
        ret = ''.join(self.cache_tput[o] for o in newcolors)
        # print(ret + "test")
        return ret


    def __getattr__(self, name):
        return self.get(name)


class _EWMH(EWMH):
    TOGGLE = 2
    ENABLE = 1
    DISABLE = 0

    def commit(self):
        self.display.flush()

    def _LastActiveWin(self, identifier, write=False):
        last_active_wid_fpath = "/tmp/LAST_%s_WID" % identifier
        if write:
            with open(last_active_wid_fpath, 'w') as f:
                f.write(str(write.id))
        else:
            win = None
            last_active_winid = None
            with open(last_active_wid_fpath, 'r') as f:
                last_active_winid = f.read().strip()
                logthis('last_active_winid={0}', last_active_winid)
            if last_active_winid:
                win = self.getWindowById(int(last_active_winid))
            if not win:
                raise Exception('WindowNotFound')
            return win

    def _first(self, gen):
        li = list(gen)
        if not li:
            return None
        elif len(li) == 1:
            return li[0]
        else:
            d = self.getCurrentDesktop()
            return sorted(li, key=lambda w: abs(d-self.getWmDesktop(w)))[0]

    def _closest(self, gen):
        li = list(gen)
        if not li:
            return None
        elif len(li) == 1:
            return li
        else:
            d = self.getCurrentDesktop()
            same_d = sorted([w for w in li if d == self.getWmDesktop(w)],
                            key=lambda w: w.id
                            )
            if same_d:
                return same_d
            return sorted(li, key=lambda w: abs(d-self.getWmDesktop(w)))

    def newWindow(self, name, tcmd, opt):
        logthis("Name     : {0}", name)
        logthis("Command  : {0}", " ".join(tcmd))
        env = os.environ.copy()
        env['WINDOW_NAME'] = name
        env['TERM'] = ''

        current_active_win = self.getActiveWindow()
        if current_active_win:
            if opt.leave_fullscreen_on_focus_change:
                fullscreen = self.getWmState(current_active_win,
                                             '_NET_WM_STATE_FULLSCREEN')
                if fullscreen:
                    self.setWmState(current_active_win, 0,
                                    '_NET_WM_STATE_FULLSCREEN')

        proc = subprocess.Popen(tcmd or name, env=env)
        if not proc.pid:
            return None

        logthis("PID={0}", proc.pid)

        w = None
        if proc._child_created:
            for i in range(100):  # try to poll during 10s
                if not proc.poll():
                    break
                w = self.getWindowByPid(proc.pid)
                if w:
                    break
                time.sleep(0.1)
        else:
            w = self.getWindowByPid(proc.pid)

        if w:
            self.setActiveWindow(w)
        elif w:  # extreme case : the process died and disown
            time.sleep(1)
            new_active_win = self.getActiveWindow()
            if (new_active_win and (
                    not current_active_win or
                    new_active_win.id != current_active_win.id
            )):
                w = new_active_win

        if w and current_active_win:
            self._LastActiveWin(w.id, write=current_active_win)
        return w

    def setActiveWindow(self, win):
        # double launch to ensure window is really activated (Buggy with Mate)
        super().setActiveWindow(win)
        super().setActiveWindow(win)

    def activateWindow(self, win_list, opt):
        current_active_win = self.getActiveWindow()
        if not win_list:
            return None

        win = win_list[0]

        if current_active_win:
            logthis("current_active_wid={0}", current_active_win.id)
            if current_active_win in win_list:
                idx = win_list.index(current_active_win)
                if (idx + 1) < len(win_list):
                    win = win_list[idx+1]
                else:
                    try:
                        win = self._LastActiveWin(win.id)
                    except:
                        return win
            if win.id != current_active_win.id and current_active_win not in win_list:
                for w in win_list:
                    self._LastActiveWin(w.id, write=current_active_win)

        logthis('window_to_activate={0}', win.id)
        if current_active_win and opt.leave_fullscreen_on_focus_change:
            fullscreen = self.getWmState(current_active_win,
                                         '_NET_WM_STATE_FULLSCREEN')
            if fullscreen:
                self.setWmState(current_active_win, 0,
                                '_NET_WM_STATE_FULLSCREEN')

        if not opt.bring_window_here:
            curdesktop = self.getCurrentDesktop()
            d = self.getWmDesktop(win)
            if curdesktop != d:
                self.setCurrentDesktop(d)
                self.display.flush()
                time.sleep(0.1)

        self.setActiveWindow(win)

        self.display.flush()
        return win

    # def getWmName(self, win):
    #     # override
    #     name = win.get_full_text_property(357) or win.get_wm_name()
    #     return '' if not isinstance(name, str) else name

    def _win_text_property(self, win):
        # workaround ewmh changes
        if hasattr(win, 'get_full_text_property'):
            return win.get_full_text_property(357)
        else:
            prop = win.get_full_property(357, X.AnyPropertyType)
            if prop is None or prop.format != 9:
                return None
            if prop.property_type == Xatom.STRING:
                prop.value = prop.value.decode(win._STRING_ENCODING)
            elif prop.property_type == win.display.get_atom('UTF8_STRING'):
                prop.value = prop.value.decode(win._UTF8_STRING_ENCODING)
            return prop.value

    def _testSearchByName(self, name, win, rx):
        # wname = self.getWmName(win)
        res = False
        if rx is not None:
            wname = self._win_text_property(win) or win.get_wm_name() or ''
            res = re.match(name, str(wname), rx) if wname else False
        else:
            wname =  win.get_wm_name() or self._win_text_property(win) or ''
        return res or name == wname

    def _testSearchByClassName(self, name, win, rx):
        classes = win.get_wm_class()
        if not classes:
            return False
        if rx:
            return any(a for a in classes if re.match(name, a, rx))
        else:
            if name.islower():
                classes = [a.lower() for a in classes]
            return name in classes

    def getWindowById(self, win_id):
        return self._first(
            w for w in self.getClientList()
            if w.id == win_id
        )

    def getWindowByName(self, name, rx=None):
        return self._closest(
            w for w in self.getClientList()
            if self._testSearchByName(name, w, rx)
        )

    def getWindowByClassName(self, name, rx=None):
        return self._closest(
            w for w in self.getClientList()
            if self._testSearchByClassName(name, w, rx)
        )

    def getWindowByPid(self, pid):
        return self._closest(
            w for w in self.getClientList()
            if self.getWmPid(w) == pid and w.id
        )

    def getWindowFromStr(self, name, opt):
        return (
            self.getWindowByName(name) or
            self.getWindowByClassName(name) or
            opt.regex and (
                self.getWindowByName(name, rx=opt.re_flag) or
                self.getWindowByClassName(name, rx=opt.re_flag)
            )
        )

    def getWinInfo(self, w):
        infos = {}
        infos['pid'] = self.getWmPid(w) 
        infos['class'] = ','.join(w.get_wm_class()) or ''
        infos['name'] = w.get_wm_name() or ''
        infos['title'] = w.get_full_text_property(357) or ''
        infos['id'] = w.id
        infos['xid'] = "0x%.8x" % w.id
        return infos

    def showWindowList(self, opt):
        color = Colors(opt)
        curr = self.getActiveWindow()
        print_format = {"xid": {'len': 10, 'color': 'mag'},
                        "id": {'len': 8, 'color': 'gre'},
                        "pid": {'len': 5, 'color': 'gre'},
                        "class": {'len': 21, 'color': 'yol'},
                        "name": {'len': 50, 'color': 'mag'},
                        "title": {'len': 32, 'color': 'yel'}
                        }
        column_names = ['id', 'pid', 'class', 'title']
        def _printlist(wins):
            fmt = ' '.join("%s{%s:%d}" % (color.get(print_format[c]['color']), c, print_format[c]['len'])
                    for c in column_names) + color.rs
            fmttitle = ' '.join("%s{%s:%d}" % (color.get(print_format[c]['color']) + color.title, c, print_format[c]['len'])
                    for c in column_names) + color.rs
            fmtactiv = ' '.join("%s{%s:%d}" % (color.get(print_format[c]['color']) + color.rev, c, print_format[c]['len'])
                    for c in column_names) + color.rs
            if opt.list_with_header:
                print(color.bold + fmttitle.format(
                    **{k: k.capitalize() for k in column_names}))
            for win in wins:
                if win.id == curr.id:
                    print(fmtactiv.format(**self.getWinInfo(win)))
                else:
                    print(fmt.format(**self.getWinInfo(win)))

        if opt.column_names:
            column_names = opt.column_names.split(',')

        if opt.search_name:
            name = opt.search_name
            _printlist([win for win in self.getClientList()
                        if self._testSearchByClassName(name, win, opt.re_flag) or
                        self._testSearchByClassName(name, win,  opt.re_flag)
                        ])
        else:
            _printlist(self.getClientList())

    def placeWindow(self, win, coord):
        if not re.match("([-+*/]?[0-9.]+[%c]?[, ]?)+", coord):
            logthis('unexpected coordonates : "{0}"',  coord)
            return

        g = win.get_geometry()
        g_abs = g.root.translate_coords(win, g.x, g.y)
        c_win = [g_abs.x, g_abs.y, g.width, g.height]
        c_desk = list(self.getDesktopGeometry()) * 2

        def _eval(c, i):
            if not c:
                return c_win[i]
            b = ""
            if re.match('^[-+*/]', c):
                b = str(c_win[i])
            elif 'c' in c or '%' in c:
                b = str(c_desk[i])

            def _percent(m):
                return '*' + m.groups()[0] + '/100'
            return round(eval(b + re.sub('(\d+)[%c]', _percent, c)))

        (x, y, width, height) = [_eval(c, i) for i, c in
                                 enumerate(
            (re.findall("[-+*/]?[0-9.]+[%c]?", coord)
             + [None] * 4)[:4])
        ]
        logthis('move window {0} by {1}', win.get_wm_name(), coord)
        self.setMoveResizeWindow(win, x=max([x-g.x, 0]), y=max([y-g.y, 0]),
                                 w=(width-g.x), h=(height-g.y))
        self.commit()


def get_term_open_cmd(opt):
    defterm = _exec(
        'readlink /etc/alternatives/x-terminal-emulator | xargs basename'
    )
    all_terms = [t for t in sum([tg[1][0] for tg in _term_groups], [])]
    if defterm not in all_terms:
        if not _exec(defterm + ' --help 2> /dev/null | grep -- -T'):
            for t in all_terms:
                if _exec('which ' + t):
                    defterm = t
                    break
    for (_, (terms, optformat)) in _term_groups:
        if defterm in terms:
            opts = [o.format(opt.name) for o in optformat]

    if opt.termopts:
        opts += opt.termopts.split(' ')
    if opt.termexec:
        opts += ['-e'] + opt.termexec.split(' ')

    logthis("Using -- {0} {1} --", defterm, " ".join(opts))
    return [defterm] + opts


def main():
    ewmh = _EWMH()

    parser = OptionParser()
    parser.allow_interspersed_args = False
    parser.set_description('Jump between windows')
    parser.set_usage('{0} [option] name [cmd]'.format(sys.argv[0]))

    _state_change = {
        'oncurrent': {
            'fullscreen': ewmh.TOGGLE,
            'maximize': ewmh.TOGGLE,
        },
        'onfound': {
            'fullscreen': ewmh.ENABLE,
            'maximize': ewmh.ENABLE,
        }
    }
    # Terminal facilities
    parser.add_option(
        '-t', '--terminal', action='store_true', dest='termmode',
        default=False,
        help='open a terminal nammed "{1}" ("{0}")'.format(
            default_termname, default_termname % 'name'))
    parser.add_option(
        '-T', '--terminal-name', action='store', dest='termname', default=None,
        help='open a terminal nammed using a printf like parameter')
    parser.add_option(
        '--t-e', '--terminal-exec', action='store', dest='termexec',
        default=None,
        help='start terminal with -e')
    parser.add_option(
        '--t-o', '--terminal-opts', action='store', dest='termopts',
        default=None,
        help='start terminal with opts')
    # Id search
    parser.add_option(
        '-P', '--pid', action='store', dest='search_pid', default=None)
    parser.add_option(
        '-I', '--id', action='store', dest='search_id', default=None)
    # Regexp search
    parser.add_option(
        '-r', '--regex', action='store', dest='regex', default=None,
        help='search using a regular expression (voir python re)')
    parser.add_option(
        '-i', '--ignore-case', action='store_const', const=re.IGNORECASE,
        dest='re_flag', default=None,
        help='ignore case')
    # Show window list
    parser.add_option(
        '-l', '--list', action='store_true', dest='do_list', default=None,
        help='list windows')
    parser.add_option(
        '-c', '--columns', action='store', dest='column_names', default=None,
        help='e.g. id,xid,pid,class,name'
    )
    parser.add_option(
        '-H', '--no-header', action='store_false', dest='list_with_header',
        default=True)
    parser.add_option(
        '-C', '--no-colors', action='store_false', dest='with_colors',
        default=True)
    # Place window
    parser.add_option(
        '-p', '--place', action='store', dest='coord', default=None,
        help='place window at x,y,w,h')
    parser.add_option(
        '-m', '--move', action='store', dest='move', default=None,
        help='move window at x,y,w,h')
    parser.add_option(
        '-f', '--fullscreen', action='store_true', dest='fullscreen',
        default=None
    )
    parser.add_option(
        '-F', '--leave-fullscreen', action='store_true',
        dest='leave_fullscreen_on_focus_change', default=None,
        help='leave fullscreen on focus change (for i3)'
    )
    parser.add_option(
        '-M', '--maximize', action='store_true', dest='maximize',
        default=None
    )
    parser.add_option(
        '-b', '--bring', action='store_true',
        dest='bring_window_here',
        help='bring window in current workspace',
        default=None
    )

    def _complete_opts(opt, args):
        opt.name = None
        if args:
            (wname, opt.cmd) = (args[0], args[1:])
            if opt.termexec or opt.termopts or opt.termname:
                opt.termmode = True
            if opt.termmode:
                wname = (opt.termname or default_termname) % wname
            opt.name = wname
            if not opt.search_id and re.match(r"^\d{8}\d*$", opt.name):
                opt.search_id = opt.name
        if opt.search_pid:
            opt.search_pid = int(opt.search_pid)
        if opt.search_id:
            opt.search_id = int(opt.search_id)
        opt.search_name = opt.regex or opt.name
        if opt.re_flag is not None:
            opt.regex = True
        elif opt.regex:
            opt.re_flag = 0
        return opt

    opt = _complete_opts(* parser.parse_args())
    if opt.do_list:
        ewmh.showWindowList(opt)
        exit()
    if opt.search_id:
        wl = ewmh.getWindowById(opt.search_id)
    elif opt.search_pid:
        wl = ewmh.getWindowByPid(opt.search_pid)
    elif opt.search_name:
        wl = ewmh.getWindowFromStr(opt.search_name, opt)
    state_change = _state_change['onfound']
    if wl:
        if opt.move:
            ewmh.placeWindow(wl[0], opt.move)
            w = wl[0]
        else:
            w = ewmh.activateWindow(wl, opt)
    elif opt.name:
        if opt.termmode and not opt.cmd:
            opt.cmd = get_term_open_cmd(opt)
        w = ewmh.newWindow(opt.name, opt.cmd, opt)
        if opt.coord:
            ewmh.placeWindow(w, opt.coord)
    else:
        w = ewmh.getActiveWindow()
        state_change = _state_change['oncurrent']
        if opt.move:
            ewmh.placeWindow(w, opt.move)

    if opt.fullscreen:
        ewmh.setWmState(w, state_change['fullscreen'],
                        '_NET_WM_STATE_FULLSCREEN')
    if opt.maximize:
        ewmh.setWmState(w, state_change['maximize'],
                        '_NET_WM_STATE_MAXIMIZED_VERT',
                        '_NET_WM_STATE_MAXIMIZED_HORZ')
    ewmh.commit()


if __name__ == '__main__':
    main()
    exit(0)
