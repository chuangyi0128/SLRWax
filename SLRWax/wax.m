//
//  ObjLua.m
//  Lua
//
//  Created by ProbablyInteractive on 5/27/09.
//  Copyright 2009 Probably Interactive. All rights reserved.
//

#import "ProtocolLoader.h"

#import "wax.h"
#import "wax_class.h"
#import "wax_instance.h"
#import "wax_struct.h"
#import "wax_helpers.h"
#import "wax_gc.h"
#import "wax_server.h"
#import "wax_stdlib.h"

#import "lauxlib.h"
#import "lobject.h"
#import "lualib.h"

#import "LDAOPAspect.h"


static void addGlobals(lua_State *L);
static int waxRoot(lua_State *L);
static int waxPrint(lua_State *L);
static int tolua(lua_State *L);
static int toobjc(lua_State *L);
static int exitApp(lua_State *L);
static int objcDebug(lua_State *L);

static NSMutableArray *replacedMethodArray;
static NSMutableArray *modifiedClassArray;

static lua_State *currentL;
lua_State *wax_currentLuaState() {
    
    if (!currentL) 
        currentL = lua_open();
    
    return currentL;
}

void uncaughtExceptionHandler(NSException *e) {
    NSLog(@"ERROR: Uncaught exception %@", [e description]);
    lua_State *L = wax_currentLuaState();
    
    if (L) {
        wax_getStackTrace(L);
        const char *stackTrace = luaL_checkstring(L, -1);
        NSLog(@"%s", stackTrace);
        lua_pop(L, -1); // remove the stackTrace
    }
}

int wax_panic(lua_State *L) {
	printf("Lua panicked and quit: %s\n", luaL_checkstring(L, -1));
	exit(EXIT_FAILURE);
}

lua_CFunction lua_atpanic (lua_State *L, lua_CFunction panicf);

void wax_setup() {
	NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler); 
	
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager changeCurrentDirectoryPath:[[NSBundle mainBundle] bundlePath]];
    
    lua_State *L = wax_currentLuaState();
	lua_atpanic(L, &wax_panic);
    
    luaL_openlibs(L); 

	luaopen_wax_class(L);
    luaopen_wax_instance(L);
    luaopen_wax_struct(L);
	
    addGlobals(L);
	
	[wax_gc start];
}

void wax_start(char* initScript, lua_CFunction extensionFunction, ...) {
	wax_setup();
	
	lua_State *L = wax_currentLuaState();
	
	// Load extentions
	// ---------------
	if (extensionFunction) {
        extensionFunction(L);
		
        va_list ap;
        va_start(ap, extensionFunction);
        while((extensionFunction = va_arg(ap, lua_CFunction))) extensionFunction(L);
		
        va_end(ap);
    }

	// Load stdlib
	// ---------------
	#ifdef WAX_STDLIB 
		// If the stdlib was autogenerated and included in the source, load
		char stdlib[] = WAX_STDLIB;
		size_t stdlibSize = sizeof(stdlib);
	#else
		char stdlib[] = "require 'wax'";
		size_t stdlibSize = strlen(stdlib);
	#endif

	if (luaL_loadbuffer(L, stdlib, stdlibSize, "loading wax stdlib") || lua_pcall(L, 0, LUA_MULTRET, 0)) {
		fprintf(stderr,"Error opening wax scripts: %s\n", lua_tostring(L,-1));
	}

	// Run Tests or the REPL?
	// ----------------------
	NSDictionary *env = [[NSProcessInfo processInfo] environment];
    if ([[env objectForKey:@"WAX_TEST"] isEqual:@"YES"]) {
		printf("Running Tests\n");
		if (luaL_dostring(L, "require 'tests'") != 0) {
			fprintf(stderr,"Fatal error running tests: %s\n", lua_tostring(L,-1));
        }
        exit(1);
    }
	else if ([[env objectForKey:@"WAX_REPL"] isEqual:@"YES"]) {
		printf("Starting REPL\n");
		if (luaL_dostring(L, "require 'wax.repl'") != 0) {
            fprintf(stderr,"Fatal error starting the REPL: %s\n", lua_tostring(L,-1));
        }		
		exit(1);
	}
	else {
		// Load app
		char appLoadString[512];
		snprintf(appLoadString, sizeof(appLoadString), "local f = '%s' require(f:gsub('%%.[^.]*$', ''))", initScript); // Strip the extension off the file.
		if (luaL_dostring(L, appLoadString) != 0) {
			fprintf(stderr,"Error opening wax scripts: %s\n", lua_tostring(L,-1));
		}
	}

}

void wax_startWithServer() {		
	wax_setup();
	[wax_server class]; // You need to load the class somehow via the wax.framework
	lua_State *L = wax_currentLuaState();
	
	// Load all the wax lua scripts
    if (luaL_dofile(L, WAX_SCRIPTS_DIR "/scripts/wax/init.lua") != 0) {
        fprintf(stderr,"Fatal error opening wax scripts: %s\n", lua_tostring(L,-1));
    }
	
	Class WaxServer = objc_getClass("WaxServer");
	if (!WaxServer) [NSException raise:@"Wax Server Error" format:@"Could load Wax Server"];
	
	[WaxServer start];
}

/// 重置所有被wax修改的方法和类
void wax_clear() {
    // methods rollback
    for (NSDictionary *dict in replacedMethodArray) {
        Class class = dict[@"class"];
        NSString *sel_str = dict[@"sel"];
        NSString *sel_objc_str = dict[@"sel_objc"];
        NSString *typeDesc = dict[@"typeDesc"];
        NSString *identifier = dict[@"identifier"];
        if (identifier) {
            [[LDAOPAspect instance] removeAnInterceptorWithIdentifier:identifier];
        }
        
        if (sel_str && ![sel_str isKindOfClass:[NSNull class]]
            && sel_objc_str && ![sel_objc_str isKindOfClass:[NSNull class]]
            && typeDesc && ![typeDesc isKindOfClass:[NSNull class]]) {
            SEL sel = NSSelectorFromString(sel_str);
            SEL sel_objc = NSSelectorFromString(sel_objc_str); // objcXXXX
            IMP imp = class_getMethodImplementation(class, sel_objc);
            class_replaceMethod(class, sel, imp, typeDesc.UTF8String);
        }
    }
    
    [replacedMethodArray removeAllObjects];
    [replacedMethodArray release];
    replacedMethodArray = nil;
    
    // class rollback
    for (NSDictionary *dict in modifiedClassArray) {
        NSString *className = dict[@"class"];
        NSInteger version = [dict[@"version"] intValue];
        Class class = NSClassFromString(className);
        class_setVersion(class, version);
    }
    [modifiedClassArray removeAllObjects];
    [modifiedClassArray release];
    modifiedClassArray = nil;
}

void wax_end() {
    wax_clear();
    [wax_gc stop];
    lua_close(wax_currentLuaState());
    currentL = 0;
}

void addMethodReplaceDict(NSDictionary *dict) {
    if (replacedMethodArray == nil) {
        replacedMethodArray = [[NSMutableArray alloc] init];
    }
    [replacedMethodArray addObject:dict];
}

void addClassModifyDict(NSDictionary *dict) {
    if (modifiedClassArray == nil) {
        modifiedClassArray = [[NSMutableArray alloc] init];
    }
    [modifiedClassArray addObject:dict];
}

static void addGlobals(lua_State *L) {
    lua_getglobal(L, "wax");
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1); // Get rid of the nil
        lua_newtable(L);
        lua_pushvalue(L, -1);
        lua_setglobal(L, "wax");
    }
    
    lua_pushnumber(L, WAX_VERSION);
    lua_setfield(L, -2, "version");
    
    lua_pushstring(L, [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] UTF8String]);
    lua_setfield(L, -2, "appVersion");
    
    lua_pushcfunction(L, waxRoot);
    lua_setfield(L, -2, "root");

    lua_pushcfunction(L, waxPrint);
    lua_setfield(L, -2, "print");    
    
#ifdef DEBUG
    lua_pushboolean(L, YES);
    lua_setfield(L, -2, "isDebug");
#endif
    
    lua_pop(L, 1); // pop the wax global off
    

    lua_pushcfunction(L, tolua);
    lua_setglobal(L, "tolua");
    
    lua_pushcfunction(L, toobjc);
    lua_setglobal(L, "toobjc");
    
    lua_pushcfunction(L, exitApp);
    lua_setglobal(L, "exitApp");
    
    lua_pushstring(L, [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] UTF8String]);
    lua_setglobal(L, "NSDocumentDirectory");
    
    lua_pushstring(L, [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0] UTF8String]);
    lua_setglobal(L, "NSLibraryDirectory");
    
    NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    lua_pushstring(L, [cachePath UTF8String]);
    lua_setglobal(L, "NSCacheDirectory");

    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:cachePath withIntermediateDirectories:YES attributes: nil error:&error];
    if (error) {
        wax_log(LOG_DEBUG, @"Error creating cache path. %@", [error localizedDescription]);
    }
}

static int waxPrint(lua_State *L) {
    NSLog(@"%s", luaL_checkstring(L, 1));
    return 0;
}

static int waxRoot(lua_State *L) {
    luaL_Buffer b;
    luaL_buffinit(L, &b);
    luaL_addstring(&b, WAX_SCRIPTS_DIR);
    
    for (int i = 1; i <= lua_gettop(L); i++) {
        luaL_addstring(&b, "/");
        luaL_addstring(&b, luaL_checkstring(L, i));
    }

    luaL_pushresult(&b);
                       
    return 1;
}

static int tolua(lua_State *L) {
    if (lua_isuserdata(L, 1)) { // If it's not userdata... it's already lua!
        wax_instance_userdata *instanceUserdata = (wax_instance_userdata *)luaL_checkudata(L, 1, WAX_INSTANCE_METATABLE_NAME);
        wax_fromInstance(L, instanceUserdata->instance);
    }
    
    return 1;
}

static int toobjc(lua_State *L) {
    id *instancePointer = wax_copyToObjc(L, "@", 1, nil);
    id instance = *(id *)instancePointer;
    
    wax_instance_create(L, instance, NO);
    
    if (instancePointer) free(instancePointer);
    
    return 1;
}

static int exitApp(lua_State *L) {
    exit(0);
    return 0;
}