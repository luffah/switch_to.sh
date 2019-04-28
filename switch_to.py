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
# import termios
import subprocess
from datetime import datetime
from collections import OrderedDict
from optparse import OptionParser
from ewmh import EWMH

logfile = sys.stderr
DEBUG = os.environ.get('DEBUG', False)

_term_groups = OrderedDict([
    ('st', (['st', 'stterm'],
            ["-t", "{0}", "-c", "{0}"])),
    ('mate', (['lxterminal', 'mate-terminal', 'mate-terminal.wrapper'],
              ["-t", "{0}"])),
    ('*', (['xterm', 'rxvt', 'xfce4-terminal', 'lxterm', 'koi8rxterm', 'mlterm',
            'uxterm', 'xfce4-terminal.wrapper', 'terminator'],
           ["-T", "{0}"]))
])
default_termname = '.t.%s.'

def _exec(oscmd):
    return os.popen(oscmd).read().strip()

def _first(gen):
    li = list(gen)
    return li[0] if li else None

def logthis(txt, *args):
    if DEBUG:
        print("{0} {1}".format(
            datetime.now(), txt.format(*args)), file=logfile)


class Colors():
    color_tab = {}
    _color_tab = {
        'rs': ('sgr0',),
        'bold': ('bold',),
        'rev': ('bold', 'rev'),
        'grt': ('setaf 2', 'bold', 'smul'),
        'mag': ('setaf 5',),
        'yel': ('setaf 3',),
        'yol': ('setaf 6',),
    }

    def __getattr__(self, name):
        if not name in self.color_tab and name in self._color_tab:
            self.color_tab[name] = _exec(
                ";".join(['tput ' + o for o in self._color_tab[name]]))
        return self.color_tab[name]



class _EWMH(EWMH):
    TOGGLE = 2
    ENABLE = 1
    DISABLE = 0

    def commit(self):
        self.display.flush()

    def _LastActiveWin(self, name, write=False):
        def _translate(name):
            return name.replace(
                ' ', '').replace(
                    '/', '')

        last_active_wid_fpath = "/tmp/LAST_%s_WID" % _translate(name)
        if write:
            with open(last_active_wid_fpath, 'w') as f:
                f.write(str(write.id))
        else:
            win=None
            last_active_winid=None
            with open(last_active_wid_fpath, 'r') as f:
                last_active_winid = f.read().strip()
                logthis('last_active_winid={0}', last_active_winid)
            if last_active_winid:
                win = self.getWindowById(int(last_active_winid))
            if not win:
                raise Exception('WindowNotFound')
            return win

    def newWindow(self, name, tcmd, opt):
        logthis("Name     : {0}", name)
        logthis("Command  : {0}", " ".join(tcmd))
        env = os.environ.copy()
        env['WINDOW_NAME'] = name
        env['TERM'] = ''

        current_active_win = self.getActiveWindow()
        if opt.leave_fullscreen_on_focus_change:
            fullscreen = self.getWmState(current_active_win,
                                         '_NET_WM_STATE_FULLSCREEN')
            if fullscreen:
                self.setWmState(current_active_win, 0,
                                '_NET_WM_STATE_FULLSCREEN')
        self._LastActiveWin(name, write=current_active_win)

        proc = subprocess.Popen(tcmd or name, env=env)
        if not proc.pid:
            return None
        logthis("PID={0}", proc.pid)
        # FIXME: find a less agressive way to get the new window
        while True:
            time.sleep(0.01)
            w = self.getWindowByPid(proc.pid)
            if w and w.id in [w.id for w in self.getClientList()]:
                return w
            new_active_win = self.getActiveWindow()
            if new_active_win.id != current_active_win.id:
                return new_active_win

    def activateWindow(self, win, name, opt):
        current_active_win = self.getActiveWindow()
        logthis("current_active_wid={0}", current_active_win.id)
        logthis('window_to_activate={0}', win.id)

        if win.id == current_active_win.id:
            try:
                win = self._LastActiveWin(name)
            except:
                return win
        else:
            self._LastActiveWin(name, write=current_active_win)

        if win:
            logthis('window_to_activate={0}', win.id)
            if opt.leave_fullscreen_on_focus_change:
                fullscreen = self.getWmState(current_active_win,
                                            '_NET_WM_STATE_FULLSCREEN')
                if fullscreen:
                    self.setWmState(current_active_win, 0,
                                '_NET_WM_STATE_FULLSCREEN')

            self.setActiveWindow(win)

        return win

    def getWmName(self, win):
        # override
        name = win.get_wm_name()
        return '' if not isinstance(name, str) else name

    def _testSearchByName(self, name, win, rx):
        wname = self.getWmName(win)
        return rx is not None and re.match(name, wname, rx) or name == wname

    def _testSearchByClassName(self, name, win, rx):
        classes = win.get_wm_class()
        return rx is not None and any(
            a for a in classes if re.match(name, a, rx)) or name in classes

    def getWindowById(self, win_id):
        return _first(
            w for w in self.getClientList()
            if w.id == win_id
        )

    def getWindowByName(self, name, rx=None):
        return _first(
            w for w in self.getClientList()
            if self._testSearchByName(name, w, rx)
        )

    def getWindowByClassName(self, name, rx=None):
        return _first(
            w for w in self.getClientList()
            if self._testSearchByClassName(name, w, rx)
        )

    def getWindowByPid(self, pid):
        return _first(
            w for w in self.getClientList()
            if self.getWmPid(w) == pid
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

    def showWindowList(self, opt):
        color = Colors()
        curr = self.getActiveWindow()

        def _printrow(*args, hl=False, title=False):
            print("%s%-5s%-16s%-16s %-50s%s" % (
                hl and color.rev or title and color.bold or "",
                *args, color.rs))

        def _printlist(wins):
            if opt.list_with_header:
                _printrow('Pid', 'Class', '', 'Name', title=True)
            for win in wins:
                _printrow(
                    self.getWmPid(win),
                    * win.get_wm_class(),
                    win.get_wm_name(),
                    hl=(win.id == curr.id)
                )


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
        self.setMoveResizeWindow(win, x=max([x-g.x,0]), y=max([y-g.y,0]), w=width, h=height)

# def getch():
#     fd = sys.stdin.fileno()
#     rs = termios.tcgetattr(fd)
#     try:
#         tty.setraw(sys.stdin.fileno())
#         ch = sys.stdin.read(1)
#     finally:
#         termios.tcsetattr(fd, termios.TCSADRAIN, rs)
#     return ch
#
#
# def prompt():
#     sys.stdout.write(
#         "{0}\r".format(
#             "{0} Press a key to continue or 'q' to quit.{1}".format(
#                 color.rev, color.rs
#             )
#         )
#     )
#     ch = getch()
#     sys.stdout.write("${0}\r".format(" "*47))
#     if ch == 'q':
#         exit(0)
#

def get_term_open_cmd(name):
    defterm = _exec(
        'readlink /etc/alternatives/x-terminal-emulator | xargs basename'
    )
    all_terms = [t for t in sum([tg[0] for tg in _term_groups.values()], [])]
    if defterm not in all_terms:
        if not _exec(defterm + ' --help 2> /dev/null | grep -- -T'):
            for t in all_terms:
                if _exec('which ' + t):
                    defterm = t
                    break
    for (terms, optformat) in _term_groups.values():
        if defterm in terms:
            opts = [o.format(name) for o in optformat]
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
        '-H', '--no-header', action='store_false', dest='list_with_header',
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

    def _complete_opts(opt, args):
        opt.name = None
        if args:
            (wname, opt.cmd) = (args[0], args[1:])
            if opt.termname:
                opt.termmode = True
            if opt.termmode:
                wname = (opt.termname or default_termname) % wname
            opt.name = wname
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
    w = ewmh.getWindowFromStr(opt.search_name, opt)
    state_change = _state_change['onfound']
    if w:
        if opt.move:
            ewmh.placeWindow(w, opt.move)
        else:
            ewmh.activateWindow(w, opt.search_name, opt)
    elif opt.name:
        if opt.termmode and not opt.cmd:
            opt.cmd = get_term_open_cmd(opt.name)
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
