/* PiKoSoL-20K v0.1.0: VexRiscv-independent command interpreter.
 * The installed V201 gateware renders ONE rectangle. A and B are logical
 * software objects; only the currently selected one can be displayed.
 * TERM is UART-only until a separately validated text RTL exists.
 * SPDX-License-Identifier: MIT
 */
#include "pikosol_shell.h"

#define REG_ID       0x00u
#define REG_BG       0x04u
#define REG_XY       0x08u
#define REG_WH       0x0Cu
#define REG_RECT     0x10u
#define REG_STATUS   0x14u
#define REG_COMMIT   0x18u
#define STATUS_BUSY  1u
#define POLL_LIMIT   1000000u

static void put(ps_shell *s, char ch) { s->io.putc(s->io.context, ch); }
static void say(ps_shell *s, const char *p) { while (*p) put(s, *p++); }
static void hex32(ps_shell *s, uint32_t v) {
    static const char digits[] = "0123456789ABCDEF";
    unsigned shift;
    say(s, "0x");
    for (shift = 28u;; shift -= 4u) {
        put(s, digits[(v >> shift) & 15u]);
        if (!shift) break;
    }
}
/* No division or multiplication: safe for VexRiscv_Min RV32I without libgcc. */
static void dec(ps_shell *s, uint32_t n) {
    static const uint32_t places[] = {
        1000000000u,100000000u,10000000u,1000000u,100000u,
        10000u,1000u,100u,10u,1u
    };
    unsigned i;
    int started = 0;
    for (i = 0; i < 10u; ++i) {
        unsigned digit = 0;
        while (n >= places[i]) { n -= places[i]; ++digit; }
        if (digit || started || i == 9u) { put(s, (char)('0'+digit)); started=1; }
    }
}
static char upper(char c) {
    return (c >= 'a' && c <= 'z') ? (char)(c - ('a'-'A')) : c;
}
static int same(const char *p, const char *target) {
    while (*p && *target) {
        if (upper(*p++) != *target++) return 0;
    }
    return *p == 0 && *target == 0;
}
static const char *skip_spaces(const char *p) {
    while (*p == ' ' || *p == '\t') ++p;
    return p;
}
/* Parse a single required argument and reject surplus tokens. */
static char single_arg(const char *p) {
    char c;
    p = skip_spaces(p);
    if (!*p) return 0;
    c = upper(*p++);
    return (*skip_spaces(p) == 0) ? c : 0;
}
static int starts(const char *s, const char *prefix) {
    while (*prefix) { if (!*s || upper(*s) != *prefix) return 0; ++s; ++prefix; }
    return *s == ' ' || *s == '\t';
}
static int hex_rgb(const char *p, uint32_t *value) {
    uint32_t out = 0;
    unsigned i;
    p=skip_spaces(p);
    for (i=0; i<6u; ++i) {
        unsigned digit;
        char c=upper(*p++);
        if (c >= '0' && c <= '9') digit=(unsigned)(c-'0');
        else if (c >= 'A' && c <= 'F') digit=(unsigned)(c-'A'+10);
        else return 0;
        out=(out<<4)|digit;
    }
    if (*skip_spaces(p)) return 0;
    *value=out;
    return 1;
}
static int ready(ps_shell *s) {
    uint32_t i;
    for (i=0; i<POLL_LIMIT; ++i) {
        if (!(s->io.read32(s->io.context,s->io.video_base+REG_STATUS)&STATUS_BUSY))
            return 1;
    }
    return 0;
}
/* Entire snapshot staged in V201 then atomically COMMITted at frame boundary.
 * We never modify registers while BUSY or write any unknown peripheral.
 */
static int project(ps_shell *s, unsigned selected, unsigned gfx,
                   const ps_object *candidate, uint32_t bg) {
    const ps_object *o=candidate;
    uint32_t base=s->io.video_base;
    (void)selected;   /* Projection is deliberately one-rectangle hardware. */
    if (!s->video_ok) { say(s,"ERR VIDEO ID: read-only shell\r\n"); return 0; }
    if (!ready(s)) { say(s,"ERR VIDEO BUSY before write\r\n"); return 0; }
    s->io.write32(s->io.context,base+REG_BG,bg & 0xFFFFFFu);
    s->io.write32(s->io.context,base+REG_XY,((uint32_t)o->y<<16)|o->x);
    s->io.write32(s->io.context,base+REG_WH,
                  gfx ? (((uint32_t)o->h<<16)|o->w) : 0u);
    s->io.write32(s->io.context,base+REG_RECT,o->rgb & 0xFFFFFFu);
    s->io.write32(s->io.context,base+REG_COMMIT,1u);
    if (!ready(s)) { say(s,"ERR VIDEO ACK timeout; state uncertain\r\n"); return 0; }
    return 1;
}
static void status(ps_shell *s) {
    unsigned n;
    say(s,"MODE="); say(s,s->gfx ? "GFX" : "TERM(UART only)");
    say(s," SELECT=");put(s,s->selected ? 'B':'A');
    say(s," VISIBLE=ONE\r\nBG=");hex32(s,s->bg);
    say(s,"\r\n");
    for(n=0;n<2u;++n) {
        const ps_object *o=&s->obj[n];
        say(s,n ? "B: X=" : "A: X="); dec(s,o->x);
        say(s," Y=");dec(s,o->y);
        say(s," W=");dec(s,o->w);
        say(s," H=");dec(s,o->h);
        say(s," RGB=");hex32(s,o->rgb); say(s,"\r\n");
    }
}
static void help(ps_shell *s) {
    say(s,"HELP INFO STATUS GFX TERM OBJ A|B\r\n");
    say(s,"MOVE I|J|K|L COLOR R|G|U|W SIZE +|-\r\n");
    say(s,"BG RRGGBB  (6 hex digits), LED ?\r\n");
    say(s,"CR/LF commands; Backspace; Ctrl-P recall.\r\n");
    say(s,"TERM is UART-only; 2 logical objects / 1 HDMI rectangle.\r\n");
}
void ps_init(ps_shell *s, const ps_io *io) {
    s->io=*io;
    s->obj[0].x=220; s->obj[0].y=220;
    s->obj[0].w=160; s->obj[0].h=120; s->obj[0].rgb=0x00FF80u;
    s->obj[1].x=700; s->obj[1].y=310;
    s->obj[1].w=180; s->obj[1].h=100; s->obj[1].rgb=0xFF0000u;
    s->selected=0; s->gfx=0; s->len=0;
    s->history_len=0; s->ignore_lf=0;
    s->line[0]=0; s->history[0]=0;
    s->detected_id=s->io.read32(s->io.context,s->io.video_base+REG_ID);
    s->video_ok=(uint8_t)(s->detected_id==PS_VIDEO_ID);
    s->bg=s->video_ok ?
        (s->io.read32(s->io.context,s->io.video_base+REG_BG)&0xFFFFFFu) : 0x102040u;
    say(s,"\r\nPiKoSoL-20K shell v0.1 / VexRiscv / RAM-only\r\n");
    say(s,"VIDEO ID=");hex32(s,s->detected_id);
    say(s,s->video_ok ? " OK\r\n" : " MISMATCH: NO VIDEO WRITES\r\n");
    say(s,"HELP for commands; TERM output is UART only.\r\nPiKoSoL20K> ");
}
void ps_execute(ps_shell *s, const char *command) {
    char arg;
    const char *p=skip_spaces(command);
    unsigned sel=s->selected;
    ps_object o=s->obj[sel];
    if (!*p) return;
    if (same(p,"HELP")) { help(s); return; }
    if (same(p,"INFO")) {
        say(s,"PiKoSoL20K v0.1 CPU=VexRiscv_Min LiteX UART=115200 8N1\r\n");
        say(s,"UART_BASE=");hex32(s,s->io.uart_base);
        say(s," VIDEO_BASE=");hex32(s,s->io.video_base);
        say(s," ID=");hex32(s,s->detected_id);
        say(s,"\r\nHDMI 1280x720: one rectangle, no text VRAM\r\n");
        return;
    }
    if (same(p,"STATUS")) { status(s); return; }
    if (same(p,"LED ?") || same(p,"LED")) {
        say(s,"LED not mapped in EX20-05.16: no register writes.\r\n");return;
    }
    if (same(p,"GFX")) {
        if (project(s,sel,1u,&o,s->bg)) {
            s->gfx=1; say(s,"GFX: selected object on HDMI\r\n");
        }
        return;
    }
    if (same(p,"TERM")) {
        if (project(s,sel,0u,&o,s->bg)) {
            s->gfx=0;
            say(s,"TERM: rectangle hidden; UART only (no HDMI text yet)\r\n");
        }
        return;
    }
    if (starts(p,"OBJ")) {
        arg=single_arg(p+3);
        if (arg!='A' && arg!='B') goto badarg;
        sel=(unsigned)(arg-'A');
        o=s->obj[sel];
        if (s->gfx && !project(s,sel,1u,&o,s->bg)) return;
        s->selected=(uint8_t)sel;
        say(s,"SELECTED ");put(s,arg);say(s,"\r\n");return;
    }
    if (starts(p,"MOVE")) {
        arg=single_arg(p+4);
        if (arg!='I' && arg!='J' && arg!='K' && arg!='L') goto badarg;
        if (arg=='I' && o.y>=8u) o.y-=8u;
        else if (arg=='J' && o.x>=8u) o.x-=8u;
        else if (arg=='K' && (uint32_t)o.y+o.h+8u<=PS_SCREEN_H) o.y+=8u;
        else if (arg=='L' && (uint32_t)o.x+o.w+8u<=PS_SCREEN_W) o.x+=8u;
        else { say(s,"EDGE: geometry unchanged\r\n");return; }
    } else if (starts(p,"COLOR")) {
        arg=single_arg(p+5);
        switch(arg) {
            case 'R':o.rgb=0xFF0000u;break;
            case 'G':o.rgb=0x00FF00u;break;
            case 'U':o.rgb=0x0000FFu;break; /* U=blue: legacy syntax */
            case 'W':o.rgb=0xFFFFFFu;break;
            default:goto badarg;
        }
    } else if (starts(p,"SIZE")) {
        arg=single_arg(p+4);
        if (arg=='+') {
            if (o.w>=320u || (uint32_t)o.x+o.w+8u>PS_SCREEN_W) {
                say(s,"EDGE: width unchanged\r\n");return;
            }
            o.w+=8u;
        } else if (arg=='-') {
            if (o.w<=32u) { say(s,"EDGE: width unchanged\r\n");return; }
            o.w-=8u;
        } else goto badarg;
    } else if (starts(p,"BG")) {
        uint32_t candidate;
        if (!hex_rgb(p+2,&candidate)) goto badarg;
        if (!project(s,sel,s->gfx,&o,candidate)) return;
        s->bg=candidate;
        say(s,"BG updated\r\n");return;
    } else {
        say(s,"ERR unknown command; HELP\r\n");return;
    }
    /* On GFX, commit before mutating logical state. TERM edits stay in RAM. */
    if (s->gfx && !project(s,sel,1u,&o,s->bg)) return;
    s->obj[sel]=o;
    say(s,s->gfx ? "GFX updated\r\n" : "STATE updated (UART TERM; GFX to display)\r\n");
    return;
badarg:
    say(s,"ERR argument; HELP\r\n");
}
void ps_feed(ps_shell *s, unsigned char c) {
    unsigned i;
    if (c=='\n' && s->ignore_lf) { s->ignore_lf=0;return; }
    s->ignore_lf=0;
    if (c=='\r' || c=='\n') {
        if (c=='\r') s->ignore_lf=1;
        say(s,"\r\n");
        s->line[s->len]=0;
        if (s->len) {
            s->history_len=s->len;
            for (i=0;i<=s->len;++i) s->history[i]=s->line[i];
            ps_execute(s,s->line);
        }
        s->len=0; s->line[0]=0;
        say(s,"PiKoSoL20K> ");return;
    }
    if (c==8u || c==127u) {
        if (s->len) {
            --s->len;s->line[s->len]=0;
            say(s,"\b \b");
        }
        return;
    }
    if (c==16u && s->len==0 && s->history_len) {
        for (i=0;i<=s->history_len;++i) s->line[i]=s->history[i];
        s->len=s->history_len;
        for (i=0;i<s->len;++i) put(s,s->line[i]);
        return;
    }
    if (c<32u || c>126u) return;
    if (s->len>=PS_LINE_CAP-1u) { put(s,'\a'); return; }
    s->line[s->len++]=(char)c;
    s->line[s->len]=0;
    put(s,(char)c);
}
