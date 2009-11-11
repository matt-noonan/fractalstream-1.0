#ifndef DidDefineOps
#define DidDefineOps

	const int arith_binary_ops = 5;
	FSEDict arith_binary[] = { 
		{	@"+",		FSE_Add		},
		{	@"-",		FSE_Sub		},
		{	@"*",		FSE_Mul		},
		{	@"/",		FSE_Div		},
		{	@"^",		FSE_Power	}
	};
	const int arith_prefix_ops = 2;
	const FSEDict arith_prefix[] = {			// TOTALLY BROKEN!?
		{	@"-",		FSE_Neg		},
		{	@"@",		FSE_Norm2	}
	};
	const int arith_postfix_ops = 3;
	const FSEDict arith_postfix[] = {
		{	@"^*",	FSE_Conj	}, /* 0x2020 */
		{	@"^^",  FSE_Square	}, /* 0x00b2 */
		{	@"!",		FSE_Inv		},
	};
	const int bool_binary_ops = 5;
	const FSEDict bool_binary[] = {
		{	@"or",		FSE_Or		},
		{	@"and",		FSE_And		},
		{	@"xor",		FSE_Xor		},
		{	@"nor",		FSE_Nor		},
		{	@"nand",	FSE_Nand	}
	};
	const int bool_prefix_ops = 1;
	const FSEDict bool_prefix[] = {
		{	@"~",		FSE_Not		}
	};
	const int comp_command_ops = 2;
	const FSEDict comp_command[] = {
		{	@"failed",		FSE_Failed		},
		{	@"succeeded",	FSE_Succeeded	},
	};
	const int comp_binary_ops = 8;
	const FSEDict comp_binary[] = {
		{	@"=",		FSE_Equal	},
		{	@"<",		FSE_LT		},
		{	@">",		FSE_GT		},
		{	@"<=",		FSE_LTE		},
		{	@">=",		FSE_GTE		},
		{	@"~=",		FSE_NotEqual},
		{	@"=/=",		FSE_NotEqual},
		{	@"!=",		FSE_NotEqual}
	};
	const int comp_postfix_ops = 3;
	const FSEDict comp_postfix[] = {
		{	@"escapes",		FSE_Escapes	},
		{	@"stops",		FSE_Stops	},
		{	@"vanishes",	FSE_Vanishes}
	};
	const int function_ops = 19;
	const FSEDict function[] = {
		{	@"exp",		FSE_Exp		},
		{	@"cosh",	FSE_Cosh	},
		{	@"sinh",	FSE_Sinh	},
		{	@"tanh",	FSE_Tanh	},
		{	@"cos",		FSE_Cos		},
		{	@"sin",		FSE_Sin		},
		{	@"tan",		FSE_Tan		},
		{	@"log",		FSE_Log		},
		{	@"sqrt",	FSE_Sqrt	},
		{	@"re",		FSE_Re		},
		{	@"im",		FSE_Im		},
		{	@"arccos",	FSE_Arccos	},
		{	@"arcsin",	FSE_Arcsin	},
		{	@"arctan",	FSE_Arctan	},
		{	@"arg",		FSE_Arg		},
		{	@"conj",	FSE_Bar		},
		{	@"bar",		FSE_Bar		},
		{	@"random",	FSE_Random	},
		{	@"gaussian",FSE_Gaussian}
	};
	const int reserved_ops = 13;
	const FSEDict reserved[] = {
		{	@"let",			0	},
		{	@"set",			0	},
		{	@"iterate",		0	},
		{	@"until",		0	},
		{	@"hint",		0	},
		{	@"complex",		0	},
		{	@"real",		0	},
		{	@"positive",	0	},
		{	@"dynamic",		0	},
		{	@"parametric",	0	},
		{	@"escapes",		0	},
		{	@"stops",		0	},
		{	@"parse",		0	}
	};
	
#endif
