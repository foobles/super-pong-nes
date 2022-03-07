# sorry non-windows users 

# update sources manually here
# everything else should be automatic
SOURCES = playground.s chars.s render.s input.s header.s actors.s

AS = ca65
LD = ld65

BUILD_DIR = build

OBJ_DIR = $(BUILD_DIR)/obj
DEP_DIR = $(BUILD_DIR)/dep
BIN_DIR = $(BUILD_DIR)/bin

SOURCES := $(addprefix src/,$(SOURCES))
ROM = $(BIN_DIR)/super_pong.nes 
OBJECTS = $(SOURCES:src/%.s=$(OBJ_DIR)/%.o)
DEPS = $(SOURCES:src/%.s=$(DEP_DIR)/%.d) 

LDFLAGS = -C nes.cfg --obj-path $(OBJ_DIR) -o $(ROM) --dbgfile $(ROM:.nes=.dbg)
ASFLAGS = -g -o $(OBJ_DIR)/$*.o --create-dep $(DEP_DIR)/$*.d --bin-include-dir gfx/

all: $(ROM)

clean: ; @del $(BUILD_DIR) /S /Q > nul

$(ROM): $(OBJECTS) | $(BIN_DIR) 
	$(LD) $^ $(LDFLAGS)

$(BIN_DIR) $(DEP_DIR) $(OBJ_DIR): ; -mkdir $(subst /,\,$@)   

$(DEPS): 

$(OBJ_DIR)/%.o: src/%.s $(DEP_DIR)/%.d | $(DEP_DIR) $(OBJ_DIR) 
	$(AS) $< $(ASFLAGS)


-include $(DEP_DIR)/*.d 