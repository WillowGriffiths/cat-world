const std = @import("std");
const zm = @import("zmath");

pub const gl = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cDefine("GL3_PROTOTYPES", "1");
    @cInclude("GL/gl.h");

    @cInclude("GLFW/glfw3.h");
});

const stb = @cImport({
    @cInclude("stb_image.h");
});

const assimp = @cImport({
    @cInclude("assimp/cimport.h");
    @cInclude("assimp/scene.h");
    @cInclude("assimp/postprocess.h");
});

const ncurses = @cImport({
    @cInclude("ncurses.h");
});

const fonts = @cImport({
    @cInclude("fonts.h");
});

const Triangle = struct {
    vao: gl.GLuint,
    vbos: [2]gl.GLuint,
    ebo: gl.GLuint,

    indices: usize,

    model: zm.Mat,

    texture_handle: gl.GLuint,

    fn texture() gl.GLuint {
        var width: c_int = undefined;
        var height: c_int = undefined;
        var nr_channels: c_int = undefined;
        stb.stbi_set_flip_vertically_on_load(1);
        const data = stb.stbi_load("src/assets/texture.png", &width, &height, &nr_channels, 0);

        var texture_handle: gl.GLuint = undefined;
        gl.glGenTextures(1, &texture_handle);

        gl.glBindTexture(gl.GL_TEXTURE_2D, texture_handle);

        gl.glTexImage2D(gl.GL_TEXTURE_2D, 0, gl.GL_RGBA, width, height, 0, gl.GL_RGBA, gl.GL_UNSIGNED_BYTE, data);
        gl.glGenerateMipmap(gl.GL_TEXTURE_2D);

        return texture_handle;
    }

    fn load(self: *Triangle) void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
        defer _ = gpa.deinit();
        const allocator = gpa.allocator();

        const scene = assimp.aiImportFile("src/assets/Cat.obj", assimp.aiProcess_Triangulate | assimp.aiProcess_JoinIdenticalVertices);
        defer assimp.aiReleaseImport(scene);

        if (scene == null) {
            std.debug.print("Failed to load mesh!\n", .{});
            return;
        }

        const ai_mesh = scene.*.mMeshes[0];

        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.vbos[0]);
        gl.glBufferData(gl.GL_ARRAY_BUFFER, @sizeOf(assimp.struct_aiVector3D) * ai_mesh.*.mNumVertices, ai_mesh.*.mVertices, gl.GL_STATIC_DRAW);
        gl.glVertexAttribPointer(0, 3, gl.GL_FLOAT, gl.GL_FALSE, @sizeOf(assimp.struct_aiVector3D), @ptrFromInt(0));
        gl.glEnableVertexAttribArray(0);

        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.vbos[1]);
        gl.glBufferData(gl.GL_ARRAY_BUFFER, @sizeOf(assimp.struct_aiVector3D) * ai_mesh.*.mNumVertices, ai_mesh.*.mTextureCoords[0], gl.GL_STATIC_DRAW);
        gl.glVertexAttribPointer(1, 2, gl.GL_FLOAT, gl.GL_FALSE, @sizeOf(assimp.struct_aiVector3D), @ptrFromInt(0));
        gl.glEnableVertexAttribArray(1);

        const num_indices = ai_mesh.*.mNumFaces * 3;

        const ai_indices = allocator.alloc(u32, num_indices) catch return;
        defer allocator.free(ai_indices);

        for (0.., ai_mesh.*.mFaces[0..ai_mesh.*.mNumFaces]) |i, face| {
            @memcpy(ai_indices[i * 3 .. i * 3 + 3], face.mIndices[0..3]);
        }

        gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, self.ebo);
        gl.glBufferData(gl.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(u32) * num_indices, ai_indices.ptr, gl.GL_STATIC_DRAW);

        self.indices = num_indices;
    }

    fn leTriangle() Triangle {
        var triangle = Triangle{
            .vao = undefined,
            .vbos = undefined,
            .ebo = undefined,
            .indices = undefined,

            .model = zm.identity(),
            .texture_handle = Triangle.texture(),
        };

        gl.glGenVertexArrays(1, &triangle.vao);
        gl.glGenBuffers(2, &triangle.vbos);
        gl.glGenBuffers(1, &triangle.ebo);

        gl.glBindVertexArray(triangle.vao);

        triangle.load();

        return triangle;
    }

    fn draw(self: *Triangle, program: gl.GLuint) void {
        const location = gl.glGetUniformLocation(program, "model");
        gl.glUniformMatrix4fv(location, 1, gl.GL_FALSE, @ptrCast(&self.model));

        gl.glBindVertexArray(self.vao);
        gl.glBindTexture(gl.GL_TEXTURE_2D, self.texture_handle);

        gl.glDrawElements(gl.GL_TRIANGLES, @intCast(self.indices), gl.GL_UNSIGNED_INT, @ptrFromInt(0));
    }
};

fn shaders(comptime vert_path: []const u8, comptime frag_path: []const u8) gl.GLuint {
    const vert_source = @embedFile(vert_path);
    const frag_source = @embedFile(frag_path);

    const vert = gl.glCreateShader(gl.GL_VERTEX_SHADER);
    gl.glShaderSource(vert, 1, @ptrCast(&vert_source), null);
    gl.glCompileShader(vert);

    var success: c_int = 0;
    gl.glGetShaderiv(vert, gl.GL_COMPILE_STATUS, &success);
    if (success == 0) {
        var info_log: [512]u8 = undefined;
        gl.glGetShaderInfoLog(vert, 512, null, &info_log);
        std.debug.print("Failed to compile vert shader: {s}", .{info_log});
    }

    const frag = gl.glCreateShader(gl.GL_FRAGMENT_SHADER);
    gl.glShaderSource(frag, 1, @ptrCast(&frag_source), null);
    gl.glCompileShader(frag);

    gl.glGetShaderiv(frag, gl.GL_COMPILE_STATUS, &success);
    if (success == 0) {
        var info_log: [512]u8 = undefined;
        gl.glGetShaderInfoLog(frag, 512, null, &info_log);
        std.debug.print("Failed to compile frag shader: {s}", .{info_log});
    }

    const program = gl.glCreateProgram();
    gl.glAttachShader(program, vert);
    gl.glAttachShader(program, frag);
    gl.glLinkProgram(program);

    gl.glDeleteShader(vert);
    gl.glDeleteShader(frag);

    return program;
}

const Framebuffers = struct {
    buffers: [2]gl.GLuint = undefined,
    textures: [2]gl.GLuint = undefined,
    depth: gl.GLuint = undefined,

    width_pixels: i32 = undefined,
    height_pixels: i32 = undefined,

    width: i32 = undefined,
    height: i32 = undefined,

    fn init(self: *Framebuffers, width: i32, height: i32) void {
        gl.glGenFramebuffers(2, &self.buffers);
        gl.glGenTextures(2, &self.textures);
        gl.glGenRenderbuffers(1, &self.depth);

        self.width_pixels = width * 4;
        self.height_pixels = height * 8;

        self.width = width;
        self.height = height;

        gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, self.buffers[0]);
        gl.glBindTexture(gl.GL_TEXTURE_2D, self.textures[0]);
        gl.glBindRenderbuffer(gl.GL_RENDERBUFFER, self.depth);

        gl.glTexImage2D(gl.GL_TEXTURE_2D, 0, gl.GL_RGBA, self.width_pixels, self.height_pixels, 0, gl.GL_RGBA, gl.GL_UNSIGNED_BYTE, null);

        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_LINEAR);
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_LINEAR);

        gl.glRenderbufferStorage(gl.GL_RENDERBUFFER, gl.GL_DEPTH24_STENCIL8, self.width_pixels, self.height_pixels);

        gl.glFramebufferTexture2D(gl.GL_FRAMEBUFFER, gl.GL_COLOR_ATTACHMENT0, gl.GL_TEXTURE_2D, self.textures[0], 0);
        gl.glFramebufferRenderbuffer(gl.GL_FRAMEBUFFER, gl.GL_DEPTH_STENCIL_ATTACHMENT, gl.GL_RENDERBUFFER, self.depth);

        gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, self.buffers[1]);
        gl.glBindTexture(gl.GL_TEXTURE_2D, self.textures[1]);

        gl.glTexImage2D(gl.GL_TEXTURE_2D, 0, gl.GL_RED, width, height, 0, gl.GL_RED, gl.GL_UNSIGNED_BYTE, @ptrFromInt(0));
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_NEAREST);
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_NEAREST);

        gl.glFramebufferTexture2D(gl.GL_FRAMEBUFFER, gl.GL_COLOR_ATTACHMENT0, gl.GL_TEXTURE_2D, self.textures[1], 0);
    }

    fn reinit(self: *Framebuffers, width: i32, height: i32) void {
        gl.glDeleteFramebuffers(2, &self.buffers);
        gl.glDeleteTextures(2, &self.textures);

        self.init(width, height);
    }

    fn use0(self: *Framebuffers) void {
        gl.glEnable(gl.GL_BLEND);
        gl.glEnable(gl.GL_DEPTH_TEST);
        gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, self.buffers[0]);
        gl.glViewport(0, 0, self.width_pixels, self.height_pixels);
        gl.glClearColor(1.0, 1.0, 1.0, 1.0);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);
    }

    fn use1(self: *Framebuffers) void {
        gl.glDisable(gl.GL_BLEND);
        gl.glDisable(gl.GL_DEPTH_TEST);
        gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, self.buffers[1]);
        gl.glViewport(0, 0, self.width, self.height);
        gl.glClearColor(0.0, 0.0, 0.0, 1.0);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);
    }

    fn useDefault(_: *Framebuffers, window: ?*gl.GLFWwindow) void {
        gl.glDisable(gl.GL_BLEND);
        gl.glDisable(gl.GL_DEPTH_TEST);
        gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, 0);
        var width: i32 = undefined;
        var height: i32 = undefined;
        gl.glfwGetFramebufferSize(window, &width, &height);
        gl.glViewport(0, 0, width, height);
        gl.glClearColor(0.0, 0.0, 0.0, 1.0);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);
    }
};

fn getChar(chars: *const fonts.Chars, value: u8) u8 {
    const value_big: c_int = @intCast(value);
    const range = chars.max - chars.min;
    const value_adjusted = chars.min + @divTrunc(value_big * range, 255);
    var last = chars.chars[0];

    for (chars.chars) |char| {
        if (char.opacity > value_adjusted) {
            break;
        }

        last = char;
    }

    return last.character;
}

pub export fn showCat() void {
    std.debug.print("😺\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();

    const chars = fonts.getChars();

    std.debug.print("min: {}, max: {}\n", .{ chars.min, chars.max });

    const allocator = gpa.allocator();

    if (gl.glfwInit() != gl.GLFW_TRUE) {
        std.debug.print("Failed to initialise GLFW!", .{});
        return;
    }
    defer gl.glfwTerminate();

    const curses_window = ncurses.initscr();
    defer _ = ncurses.endwin();

    _ = ncurses.cbreak();
    _ = ncurses.curs_set(0);
    defer _ = ncurses.curs_set(1);

    defer _ = ncurses.flushinp();

    ncurses.wtimeout(curses_window, 0);

    gl.glfwWindowHint(gl.GLFW_CONTEXT_VERSION_MAJOR, 3);
    gl.glfwWindowHint(gl.GLFW_CONTEXT_VERSION_MINOR, 3);
    gl.glfwWindowHint(gl.GLFW_OPENGL_PROFILE, gl.GLFW_OPENGL_CORE_PROFILE);
    gl.glfwWindowHint(gl.GLFW_VISIBLE, gl.GLFW_FALSE);

    const window = gl.glfwCreateWindow(800, 600, ":3", null, null);
    if (window == null) {
        gl.glfwTerminate();
        var message: [*c]const u8 = null;
        const code = gl.glfwGetError(&message);

        std.debug.print("Failed to open window, code: {}, message: {s}", .{ code, message });
        return;
    }

    _ = gl.glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);
    gl.glfwMakeContextCurrent(window);

    gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);

    const cat_program = shaders("shaders/vert.glsl", "shaders/frag.glsl");
    const quad_allred_program = shaders("shaders/quad_vert.glsl", "shaders/allred_frag.glsl");
    const quad_program_monotone = shaders("shaders/quad_vert.glsl", "shaders/monotone_frag.glsl");
    var triangle = Triangle.leTriangle();

    gl.glUseProgram(cat_program);

    const view = zm.translation(0.0, -0.2, 1.0);
    const projection = zm.perspectiveFovLh(std.math.pi / 4.0, 800.0 / 600.0, 1.0, 100.0);

    const view_location = gl.glGetUniformLocation(cat_program, "view");
    const projection_location = gl.glGetUniformLocation(cat_program, "projection");

    gl.glUniformMatrix4fv(view_location, 1, gl.GL_FALSE, @ptrCast(&view));
    gl.glUniformMatrix4fv(projection_location, 1, gl.GL_FALSE, @ptrCast(&projection));

    var width = ncurses.getmaxx(curses_window);
    var height = ncurses.getmaxy(curses_window);

    var framebuffers = Framebuffers{};
    framebuffers.init(width, height);

    var buffers: [2][]u8 = undefined;

    buffers[0] = allocator.alloc(u8, @intCast(width * height)) catch return;
    defer allocator.free(buffers[0]);

    buffers[1] =
        allocator.alloc(u8, @intCast(width * height)) catch return;
    defer allocator.free(buffers[1]);

    var frame: u32 = 0;
    const start = gl.glfwGetTime();
    var last = start;
    while (gl.glfwWindowShouldClose(window) == gl.GLFW_FALSE) {
        const now = gl.glfwGetTime();
        //        const delta = now - last;
        last = now;

        const new_width = ncurses.getmaxx(curses_window);
        const new_height = ncurses.getmaxy(curses_window);
        const size_changed = (new_width != width) or (new_height != height);
        width = new_width;
        height = new_height;

        if (size_changed) {
            framebuffers.reinit(width, height);
            gl.glUseProgram(cat_program);
            const new_projection = zm.perspectiveFovLh(std.math.pi / 4.0, 800.0 / 600.0, 1.0, 100.0);
            gl.glUniformMatrix4fv(projection_location, 1, gl.GL_FALSE, @ptrCast(&new_projection));

            allocator.free(buffers[0]);
            buffers[0] = allocator.alloc(u8, @intCast(width * height)) catch return;

            allocator.free(buffers[1]);
            buffers[1] = allocator.alloc(u8, @intCast(width * height)) catch return;
        }

        triangle.model = zm.rotationY(@floatCast(now));

        framebuffers.use0();
        gl.glUseProgram(cat_program);
        triangle.draw(cat_program);

        framebuffers.use1();
        gl.glBindTexture(gl.GL_TEXTURE_2D, framebuffers.textures[0]);
        gl.glUseProgram(quad_program_monotone);
        gl.glDrawArrays(gl.GL_TRIANGLES, 0, 6);

        gl.glReadPixels(0, 0, width, height, gl.GL_RED, gl.GL_UNSIGNED_BYTE, buffers[frame % 2].ptr);

        framebuffers.useDefault(window);
        gl.glBindTexture(gl.GL_TEXTURE_2D, framebuffers.textures[1]);
        gl.glUseProgram(quad_allred_program);
        gl.glDrawArrays(gl.GL_TRIANGLES, 0, 6);

        gl.glfwSwapBuffers(window);
        gl.glfwPollEvents();

        //_ = ncurses.clear();

        const refresh = size_changed or frame == 0;
        for (0.., buffers[frame % 2], buffers[(frame + 1) % 2]) |pixel_i, pixel, old_pixel| {
            if (pixel != old_pixel or refresh) {
                const pixel_i_c = @as(c_int, @intCast(pixel_i));
                const x = @rem(pixel_i_c, width);
                const y = height - @divTrunc(pixel_i_c, width) - 1;
                const char = getChar(&chars, pixel);
                _ = ncurses.move(y, x);
                _ = ncurses.addch(char);
            }
        }

        _ = ncurses.refresh();

        frame += 1;

        if (now - start > 5.0) {
            break;
        }
    }
}

fn framebuffer_size_callback(_: ?*gl.GLFWwindow, width: c_int, height: c_int) callconv(.c) void {
    gl.glViewport(0, 0, width, height);
}
