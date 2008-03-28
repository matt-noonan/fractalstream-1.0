

typedef struct {
	int type;
	int parent;
	int children;
	int firstChild;
	int nextSibling;
	int cloneOf;
	int cachedAt;
	int cachePass;
	double hash;
	int hashed;
	int auxi[2]; /* auxi[0] gets used as index for return variable */
	double auxf[2];
	char name[64];
} FSEParseNode;

#define FSE_RootNode	0
#define FSE_Nil			0

#define FSE_Command		0xffffff00
#define FSE_Block		0
#define FSE_Set			1
#define FSE_Iterate		2
#define FSE_Par			3
#define FSE_Dyn			4
#define FSE_Do			5
#define FSE_Report		6
#define FSE_If			7
#define FSE_Flag		8
#define FSE_Default		9
#define FSE_Reset		10
#define FSE_Bumpdown	11
#define FSE_Clear		12
#define FSE_Repeat		13
#define FSE_Modulo		14

#define FSE_Type_Mask	0xffffff00
#define FSE_Arith		0x200
#define FSE_Add			0
#define FSE_Sub			1
#define FSE_Mul			2
#define FSE_Div			3
#define FSE_Norm		4
#define FSE_Norm2		5
#define FSE_Conj		6
#define FSE_Neg			7
#define FSE_Inv			8
#define FSE_Square		9
#define FSE_Power		10

#define FSE_Bool		0x500
#define FSE_Or			0
#define FSE_And			1
#define FSE_Xor			2
#define FSE_Nor			3
#define FSE_Nand		4
#define FSE_Not			5

#define FSE_Comp		0x100
#define FSE_Equal		0
#define FSE_LT			1
#define FSE_GT			2
#define FSE_LTE			3
#define FSE_GTE			4
#define FSE_NotEqual	5
#define FSE_Escapes		6
#define FSE_Stops		7
#define FSE_Vanishes	8

#define FSE_Var			0x400
#define FSE_Complex		0
#define FSE_Real		1
#define FSE_PosReal		2
#define FSE_Truth		3
#define FSE_C_Const		4
#define FSE_R_Const		5
#define FSE_Ident		6
#define FSE_Join		7
#define FSE_LinkedSubexpression 8
#define FSE_Constant	9
#define FSE_Variable	10
#define FSE_Counter		11

#define FSE_Func		0x300
#define FSE_Exp			0
#define FSE_Cosh		1
#define FSE_Sinh		2
#define FSE_Cos			3
#define FSE_Sin			4
#define FSE_Tan			5
#define FSE_Tanh		6
#define FSE_Log			7
#define FSE_Sqrt		8
#define FSE_Re			9
#define FSE_Im			10
#define FSE_Arccos		11
#define FSE_Arcsin		12
#define FSE_Arctan		13
