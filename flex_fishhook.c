// Copyright (c) 2013, Facebook, Inc.
// All rights reserved.
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//   * Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//   * Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//   * Neither the name Facebook nor the names of its contributors may be used to
//     endorse or promote products derived from this software without specific
//     prior written permission.
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#include <dlfcn.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <mach/mach.h>
#include <mach/vm_map.h>
#include <mach/vm_region.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>

#include "flex_fishhook.h"

#ifdef __LP64__
typedef struct mach_header_64 flex_mach_header_t;
typedef struct segment_command_64 flex_segment_command_t;
typedef struct section_64 flex_section_t;
typedef struct nlist_64 flex_nlist_t;
#define FLEX_LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT_64
#else
typedef struct mach_header flex_mach_header_t;
typedef struct segment_command flex_segment_command_t;
typedef struct section flex_section_t;
typedef struct nlist flex_nlist_t;
#define FLEX_LC_SEGMENT_ARCH_DEPENDENT LC_SEGMENT
#endif

#ifndef SEG_DATA_CONST
#define SEG_DATA_CONST  "__DATA_CONST"
#endif

// 定义rebindings_entry结构体
struct flex_rebindings_entry {
  struct flex_rebinding *rebindings;  // 改为 struct flex_rebinding 而不是 flex_rebinding_t
  size_t rebindings_nel;
  struct flex_rebindings_entry *next;
};

// 声明全局变量
static struct flex_rebindings_entry *_flex_rebindings_head;

// 声明函数原型
static int flex_prepend_rebindings(struct flex_rebindings_entry **rebindings_head,
                                  struct flex_rebinding rebindings[],
                                  size_t nel);

static int flex_perform_rebinding_with_section(struct flex_rebindings_entry *rebindings,
                                              flex_section_t *section,
                                              intptr_t slide,
                                              flex_nlist_t *symtab,
                                              char *strtab,
                                              uint32_t *indirect_symtab);

static void flex_perform_rebinding_with_image(struct flex_rebindings_entry *rebindings,
                                             const struct mach_header *header,
                                             intptr_t slide);

static void _flex_rebind_symbols_for_image(const struct mach_header *header,
                                          intptr_t slide) {
    struct flex_rebindings_entry *rebindings;
    for (rebindings = _flex_rebindings_head; rebindings != NULL; rebindings = rebindings->next) {
        flex_perform_rebinding_with_image(rebindings, header, slide);
    }
}

static void _flex_rebind_symbols(struct flex_rebindings_entry *rebindings) {
  uint32_t c = _dyld_image_count();
  for (uint32_t i = 0; i < c; i++) {
    flex_perform_rebinding_with_image(rebindings, _dyld_get_image_header(i), _dyld_get_image_vmaddr_slide(i));
  }
}

int flex_rebind_symbols(struct flex_rebinding rebindings[], size_t rebindings_nel) {
  int retval = flex_prepend_rebindings(&_flex_rebindings_head, rebindings, rebindings_nel);
  if (retval < 0) {
    return retval;
  }
  // 如果这是首次调用，请为所有已加载的镜像注册回调，以防它们在加载时未被捕获。
  if (!_flex_rebindings_head->next) {
    _dyld_register_func_for_add_image(_flex_rebind_symbols_for_image);
  }
  _flex_rebind_symbols(_flex_rebindings_head);
  return retval;
}

int flex_rebind_symbols_image(struct flex_rebinding rebindings[],
                             size_t rebindings_nel,
                             const struct mach_header *header,
                             intptr_t slide) {
  struct flex_rebindings_entry *rebindings_entry = NULL;
  int retval = flex_prepend_rebindings(&rebindings_entry, rebindings, rebindings_nel);
  if (retval < 0) {
    return retval;
  }
  flex_perform_rebinding_with_image(rebindings_entry, header, slide);
  if (rebindings_entry) {
    if (rebindings_entry->rebindings) {
      free(rebindings_entry->rebindings);
    }
    free(rebindings_entry);
  }
  return retval;
}

static int flex_prepend_rebindings(struct flex_rebindings_entry **rebindings_head,
                                  struct flex_rebinding rebindings[],
                                  size_t nel) {
  struct flex_rebindings_entry *new_entry = (struct flex_rebindings_entry *)malloc(sizeof(struct flex_rebindings_entry));
  if (!new_entry) {
    return -1;
  }
  new_entry->rebindings = (struct flex_rebinding *)malloc(sizeof(struct flex_rebinding) * nel);
  if (!new_entry->rebindings) {
    free(new_entry);
    return -1;
  }
  memcpy(new_entry->rebindings, rebindings, sizeof(struct flex_rebinding) * nel);
  new_entry->rebindings_nel = nel;
  new_entry->next = *rebindings_head;
  *rebindings_head = new_entry;
  return 0;
}

static void flex_perform_rebinding_with_image(struct flex_rebindings_entry *rebindings,
                                             const struct mach_header *header,
                                             intptr_t slide) {
  Dl_info info;
  if (dladdr(header, &info) == 0) {
    return;
  }

  flex_segment_command_t *cur_seg_cmd;
  flex_segment_command_t *linkedit_segment = NULL;
  struct symtab_command* symtab_cmd = NULL;
  struct dysymtab_command* dysymtab_cmd = NULL;

  uintptr_t cur = (uintptr_t)header + sizeof(flex_mach_header_t);
  for (uint i = 0; i < header->ncmds; i++, cur += cur_seg_cmd->cmdsize) {
    cur_seg_cmd = (flex_segment_command_t *)cur;
    if (cur_seg_cmd->cmd == FLEX_LC_SEGMENT_ARCH_DEPENDENT) {
      if (strcmp(cur_seg_cmd->segname, SEG_LINKEDIT) == 0) {
        linkedit_segment = cur_seg_cmd;
      }
    } else if (cur_seg_cmd->cmd == LC_SYMTAB) {
      symtab_cmd = (struct symtab_command*)cur_seg_cmd;
    } else if (cur_seg_cmd->cmd == LC_DYSYMTAB) {
      dysymtab_cmd = (struct dysymtab_command*)cur_seg_cmd;
    }
  }

  if (!symtab_cmd || !dysymtab_cmd || !linkedit_segment) {
    return;
  }

  uintptr_t linkedit_base = (uintptr_t)slide + linkedit_segment->vmaddr - linkedit_segment->fileoff;
  flex_nlist_t *symtab = (flex_nlist_t *)(linkedit_base + symtab_cmd->symoff);
  char *strtab = (char *)(linkedit_base + symtab_cmd->stroff);
  uint32_t *indirect_symtab = (uint32_t *)(linkedit_base + dysymtab_cmd->indirectsymoff);

  cur = (uintptr_t)header + sizeof(flex_mach_header_t);
  for (uint i = 0; i < header->ncmds; i++, cur += cur_seg_cmd->cmdsize) {
    cur_seg_cmd = (flex_segment_command_t *)cur;
    if (cur_seg_cmd->cmd == FLEX_LC_SEGMENT_ARCH_DEPENDENT) {
      if (strcmp(cur_seg_cmd->segname, SEG_DATA) != 0 &&
          strcmp(cur_seg_cmd->segname, SEG_DATA_CONST) != 0) {
        continue;
      }
      for (uint j = 0; j < cur_seg_cmd->nsects; j++) {
        flex_section_t *sect =
          (flex_section_t *)(cur + sizeof(flex_segment_command_t)) + j;
        if ((sect->flags & SECTION_TYPE) == S_LAZY_SYMBOL_POINTERS) {
          flex_perform_rebinding_with_section(rebindings, sect, slide, symtab, strtab, indirect_symtab);
        }
        if ((sect->flags & SECTION_TYPE) == S_NON_LAZY_SYMBOL_POINTERS) {
          flex_perform_rebinding_with_section(rebindings, sect, slide, symtab, strtab, indirect_symtab);
        }
      }
    }
  }
}

static int flex_perform_rebinding_with_section(struct flex_rebindings_entry *rebindings,
                                              flex_section_t *section,
                                              intptr_t slide,
                                              flex_nlist_t *symtab,
                                              char *strtab,
                                              uint32_t *indirect_symtab) {
  const bool isDataConst = strcmp(section->segname, SEG_DATA_CONST) == 0;
  uint32_t *indirect_symbol_indices = indirect_symtab + section->reserved1;
  void **indirect_symbol_bindings = (void **)((uintptr_t)slide + section->addr);
  vm_prot_t oldProtection = VM_PROT_READ;
  
  if (isDataConst) {
    oldProtection = VM_PROT_READ | VM_PROT_WRITE;
    mprotect(indirect_symbol_bindings, section->size, oldProtection);
  }
  
  for (uint i = 0; i < section->size / sizeof(void *); i++) {
    uint32_t symtab_index = indirect_symbol_indices[i];
    if (symtab_index == INDIRECT_SYMBOL_ABS || symtab_index == INDIRECT_SYMBOL_LOCAL ||
        symtab_index == (INDIRECT_SYMBOL_LOCAL   | INDIRECT_SYMBOL_ABS)) {
      continue;
    }
    uint32_t strtab_offset = symtab[symtab_index].n_un.n_strx;
    char *symbol_name = strtab + strtab_offset;
    bool symbol_name_longer_than_1 = symbol_name[0] && symbol_name[1];
    if (symbol_name_longer_than_1 && symbol_name[0] == '_') {
      symbol_name++;
    }
    struct flex_rebindings_entry *cur = rebindings;
    while (cur) {
      for (uint j = 0; j < cur->rebindings_nel; j++) {
        if (strcmp(&symbol_name[1], cur->rebindings[j].name) == 0) {
          if (cur->rebindings[j].replaced != NULL &&
              indirect_symbol_bindings[i] != cur->rebindings[j].replacement) {
            *(cur->rebindings[j].replaced) = indirect_symbol_bindings[i];
          }
          indirect_symbol_bindings[i] = cur->rebindings[j].replacement;
        }
      }
      cur = cur->next;
    }
  }
  
  if (isDataConst) {
    int protection = VM_PROT_READ;
    mprotect(indirect_symbol_bindings, section->size, protection);
  }
  
  return 0;
}
