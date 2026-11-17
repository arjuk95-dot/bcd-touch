#!/usr/bin/env python3
"""Apply after the 666 renderer patch to an isolated DXMT tree. No build/run.
Fail closed on drift; never touch stock DLLs. Queen scope is frozen at DLL init.
"""
from pathlib import Path
import sys
root=Path(sys.argv[1])
header='''#pragma once
#include "util_env.hpp"
namespace dxmt {
// Read once per module; no getenv/string work in hot calls. Other games retain
// their baseline behavior. Mode changes require a fresh game process.
inline bool queenRendererDiagnostics() {
  static const bool enabled = env::getEnvVar("BCD_QUEEN_RENDER_V2") != "1" ||
                              env::getEnvVar("BCD_QUEEN_DIAGNOSTICS") == "1";
  return enabled;
}
}
'''
changes={}
def edit(path, pairs):
    p=root/path;s=p.read_text()
    for a,b in pairs:
        assert s.count(a)==1,(path,a,s.count(a))
        s=s.replace(a,b)
    changes[p]=s
inc='#include "util_queen_diagnostics.hpp"\n'
edit('src/dxmt/dxmt_mem_census.cpp',[
    ('#include "dxmt_mem_census.hpp"\n','#include "dxmt_mem_census.hpp"\n'+inc),
    *[(name+' {',name+' {\n  if (!queenRendererDiagnostics()) return;') for name in
      ['buf_site_report(void)','dyn_census_report(void)','mem_census_report(const char *why)']]])
edit('src/d3d11/d3d11_device.cpp',[
    ('#include "d3d11_device.hpp"\n','#include "d3d11_device.hpp"\n'+inc),
    *[(name+' {',name+' {\n  if (!dxmt::queenRendererDiagnostics()) return;') for name in
      ['void BCCensusDump(const char *why)',
       'void BCCensusRecord(const D3D11_TEXTURE2D_DESC1 *d, const D3D11_SUBRESOURCE_DATA *data)',
       'extern "C" void BCCensusRecordSRV(unsigned int fmt)',
       'extern "C" void BCCensusRecordOp(unsigned int fmt, int op)']]])
edit('src/d3d11/d3d11_context_impl.cpp',[
    ('#include "util_math.hpp"\n','#include "util_math.hpp"\n'+inc),
    ('inline unsigned int BCCensusFormatOf(ID3D11Resource *r) {',
     'inline unsigned int BCCensusFormatOf(ID3D11Resource *r) {\n  if (!dxmt::queenRendererDiagnostics()) return 0;'),
    ('inline void BCStreamReport() {','inline void BCStreamReport() {\n  if (!dxmt::queenRendererDiagnostics()) return;'),
    # Failed uploads already return without running BCStreamReport. Surface
    # actual failure at its site, regardless of diagnostic mode.
    ('g_bc_stream_fail.fetch_add(1, std::memory_order_relaxed);',
     'const auto failures = g_bc_stream_fail.fetch_add(1, std::memory_order_relaxed) + 1;\n          if (failures && !(failures & (failures - 1)))\n            ERR("BC stream decode allocation failed; upload not performed", " cumulative=", failures);'),
    ('g_cp_bc_stg_unsupported.fetch_add(1, std::memory_order_relaxed);',
     'const auto failures = g_cp_bc_stg_unsupported.fetch_add(1, std::memory_order_relaxed) + 1;\n            if (failures && !(failures & (failures - 1)))\n              ERR("BC staging decode unsupported or inaccessible; copy not performed", " cumulative=", failures);'),
    ('g_cp_bc_stg_fail.fetch_add(1, std::memory_order_relaxed);',
     'const auto failures = g_cp_bc_stg_fail.fetch_add(1, std::memory_order_relaxed) + 1;\n            if (failures && !(failures & (failures - 1)))\n              ERR("BC staging decode allocation failed; copy not performed", " cumulative=", failures);')])
edit('src/dxmt/dxmt_dynamic.cpp',[
    ('#include "dxmt_mem_census.hpp"\n','#include "dxmt_mem_census.hpp"\n'+inc),
    ('const bool stats = census_id_ < DYN_CENSUS_SLOTS;',
     'const bool stats = queenRendererDiagnostics() && census_id_ < DYN_CENSUS_SLOTS;')])
# Validate all inputs before any writes.
assert 'std::count_if(' in changes[root/'src/dxmt/dxmt_dynamic.cpp'], '666 eligibility fix required'
h=root/'src/dxmt/util_queen_diagnostics.hpp'
assert not h.exists(), 'fresh isolated tree required'
h.parent.mkdir(parents=True,exist_ok=True)
h.write_text(header)
for p,s in changes.items():p.write_text(s)
print('Queen renderer production diagnostics applied; allocation/fence work unchanged')
