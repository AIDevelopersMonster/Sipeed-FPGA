/* Native functional tests: actual C parser + mocked V201 Wishbone registers.
 * DOES NOT test VexRiscv execution, Gowin, HDMI or physical UART.
 */
#include "../firmware/pikosol_shell.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>

typedef struct {
    uint32_t regs[8];
    unsigned writes, commits, status_reads;
    int force_busy, busy_after_commit;
    char output[65536];
    unsigned out_len;
} mock;
static uint32_t mread(void *c, uint32_t addr) {
    mock *m=(mock *)c;
    assert(addr>=PS_VIDEO_BASE && addr<PS_VIDEO_BASE+0x20u && (addr&3u)==0u);
    if (addr==PS_VIDEO_BASE+0x14u) {
        ++m->status_reads;
        if (m->force_busy || (m->busy_after_commit && m->commits)) return 1;
    }
    return m->regs[(addr-PS_VIDEO_BASE)>>2];
}
static void mwrite(void *c,uint32_t addr,uint32_t v) {
    mock *m=(mock *)c;
    assert(addr>=PS_VIDEO_BASE+4u && addr<=PS_VIDEO_BASE+0x18u && (addr&3u)==0u);
    assert(addr!=PS_VIDEO_BASE+0x14u);
    m->regs[(addr-PS_VIDEO_BASE)>>2]=v;
    ++m->writes;
    if (addr==PS_VIDEO_BASE+0x18u) {assert(v==1u);++m->commits;}
}
static void mputc(void *c, char ch) {
    mock *m=(mock *)c;
    assert(m->out_len < sizeof(m->output)-1u);
    m->output[m->out_len++]=ch;
    m->output[m->out_len]=0;
}
static void setup(ps_shell *s, mock *m, uint32_t id) {
    ps_io io;
    memset(m,0,sizeof(*m));
    memset(s,0,sizeof(*s));
    m->regs[0]=id;
    m->regs[1]=0x102040u;
    io.read32=mread;io.write32=mwrite;io.putc=mputc;
    io.context=m;io.video_base=PS_VIDEO_BASE;io.uart_base=0xF0003000u;
    ps_init(s,&io);
}
static void feed(ps_shell *s,const char *p) {
    while (*p) ps_feed(s,(unsigned char)*p++);
}
static void contains(const mock *m,const char *needle) {
    if (!strstr(m->output,needle)) {
        fprintf(stderr,"NOT FOUND: %s\nOUTPUT:\n%s\n",needle,m->output);
        assert(0);
    }
}
static void test_help_info_are_readonly(void) {
    ps_shell s; mock m;
    setup(&s,&m,PS_VIDEO_ID);
    assert(m.writes==0 && s.gfx==0 && s.video_ok);
    feed(&s,"help\r\ninfo\nstatus\r\nLED ?\r");
    contains(&m,"HELP INFO STATUS");
    contains(&m,"CPU=VexRiscv_Min");
    contains(&m,"UART_BASE=0xF0003000");
    contains(&m,"TERM(UART only)");
    contains(&m,"LED not mapped");
    assert(m.writes==0 && m.commits==0);
}
static void test_gfx_a_b_moves_and_colors(void) {
    ps_shell s; mock m;
    setup(&s,&m,PS_VIDEO_ID);
    feed(&s,"GFX\r\n");
    assert(m.commits==1 && m.writes==5 && s.gfx==1);
    assert(m.regs[2]==((220u<<16)|220u));
    assert(m.regs[3]==((120u<<16)|160u));
    feed(&s,"MOVE L\rCOLOR U\rOBJ B\rMOVE I\rSIZE +\r");
    assert(s.obj[0].x==228 && s.obj[0].rgb==0x0000FFu);
    assert(s.selected==1 && s.obj[1].y==302 && s.obj[1].w==188);
    assert(m.regs[2]==((302u<<16)|700u));
    assert(m.regs[3]==((100u<<16)|188u));
    assert(m.regs[4]==0xFF0000u);
    assert(m.commits==6);
    contains(&m,"SELECTED B");
}
static void test_term_and_bg_and_state(void) {
    ps_shell s;mock m;
    setup(&s,&m,PS_VIDEO_ID);
    feed(&s,"GFX\rTERM\rMOVE L\rCOLOR W\rBG 123abc\r");
    assert(s.gfx==0 && m.regs[3]==0u);
    assert(s.obj[0].x==228 && s.obj[0].rgb==0xFFFFFFu);
    assert(s.bg==0x123ABCu && m.regs[1]==0x123ABCu);
    contains(&m,"TERM: rectangle hidden; UART only");
    feed(&s,"GFX\r");
    assert(s.gfx==1 && m.regs[3]==((120u<<16)|160u));
    assert(m.regs[2]==((220u<<16)|228u));
    assert(m.regs[4]==0xFFFFFFu);
}
static void test_line_edit_recall_and_crlf(void) {
    ps_shell s;mock m;
    setup(&s,&m,PS_VIDEO_ID);
    feed(&s,"HEXP\b\bLP\r\n");
    /* HEXP + backspace twice -> HE, + LP -> HELP. */
    contains(&m,"HELP INFO STATUS");
    unsigned start=m.out_len;
    ps_feed(&s,16u); /* Ctrl-P recalls last command */
    assert(s.len==4 && strcmp(s.line,"HELP")==0);
    ps_feed(&s,'\r');ps_feed(&s,'\n');
    contains(&m,"Ctrl-P recall");
    assert(m.out_len>start && s.len==0 && s.history_len==4);
    assert(m.writes==0);
}
static void test_invalid_and_bounds(void) {
    ps_shell s;mock m;
    setup(&s,&m,PS_VIDEO_ID);
    feed(&s,"GFX\n");
    const unsigned base=m.commits;
    feed(&s,"MOVE Q\nSIZE ?\nBG ZZ0000\nWTF\n");
    contains(&m,"ERR argument");contains(&m,"ERR unknown command");
    assert(m.commits==base);
    s.obj[0].x=1120;s.obj[0].w=160;
    feed(&s,"MOVE L\nSIZE +\n");
    contains(&m,"EDGE: geometry unchanged");
    assert(s.obj[0].x==1120 && s.obj[0].w==160);
    assert(m.commits==base);
}
static void test_bad_id_guard(void) {
    ps_shell s;mock m;
    setup(&s,&m,0u);
    feed(&s,"INFO\nGFX\nTERM\nBG FFFFFF\n");
    assert(!s.video_ok && m.writes==0 && s.bg==0x102040u && !s.gfx);
    contains(&m,"MISMATCH: NO VIDEO WRITES");
    contains(&m,"ERR VIDEO ID: read-only shell");
}
static void test_busy_guards(void) {
    ps_shell s;mock m;
    setup(&s,&m,PS_VIDEO_ID);
    m.force_busy=1;
    feed(&s,"GFX\n");
    assert(m.writes==0 && !s.gfx);
    contains(&m,"ERR VIDEO BUSY before write");
    m.force_busy=0;m.busy_after_commit=1;
    feed(&s,"GFX\n");
    assert(m.commits==1 && !s.gfx);
    contains(&m,"ERR VIDEO ACK timeout; state uncertain");
}
static void test_47_character_buffer(void) {
    ps_shell s;mock m;
    setup(&s,&m,PS_VIDEO_ID);
    for (unsigned i=0;i<47u;++i) ps_feed(&s,'A');
    assert(s.len==47 && s.line[47]==0);
    ps_feed(&s,'B');assert(s.len==47);
    contains(&m,"\a");
    ps_feed(&s,'\r');
    assert(s.history_len==47 && s.len==0 && m.writes==0);
}
int main(void) {
    test_help_info_are_readonly();
    test_gfx_a_b_moves_and_colors();
    test_term_and_bg_and_state();
    test_line_edit_recall_and_crlf();
    test_invalid_and_bounds();
    test_bad_id_guard();
    test_busy_guards();
    test_47_character_buffer();
    puts("HOST PASS: 8 functional test groups, real C shell, simulated V201 registers");
}
