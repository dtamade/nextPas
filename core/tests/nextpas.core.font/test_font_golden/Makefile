PROGRAM := test_font_golden
include ../../common.mk

# Preserved from the pre-common.mk build (P5l unification): high-check
# density flags chosen deliberately for font debugging (-Criot range/
# overflow/IO checks, -Sa assertions, -gw2 debug info variant, -O1).
# Appended after the include: FPC applies the last -O switch.
FPC_FLAGS += -O1 -gw2 -Criot -Sa
