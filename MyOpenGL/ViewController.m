//
//  ViewController.m
//  MyOpenGL
//
//  Created by butter on 2019/8/5.
//  Copyright © 2019 butter. All rights reserved.
//

#import "ViewController.h"
#import <GLKit/GLKit.h>

/**
 定义顶点类型
 */
typedef struct {
    GLKVector3 positionCoord; // (X, Y, Z)
    GLKVector2 textureCoord; // (U, V)
} SenceVertex;

@interface ViewController ()

@property  (nonatomic, strong) EAGLContext *context;

@property  (nonatomic, strong) CAEAGLLayer *layer;

@property (nonatomic, assign) SenceVertex *vertices; // 顶点数组

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
     
    [self genContext];
    
    [self genBuffers];
    
    [self genTexture];
    
}

- (void)genContext {
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:self.context];
    
    self.layer = [[CAEAGLLayer alloc] init];
    self.layer.frame = self.view.bounds;
    self.layer.contentsScale = [UIScreen mainScreen].scale;
    [self.view.layer addSublayer:self.layer];
    
    // 创建顶点数组
    self.vertices = malloc(sizeof(SenceVertex) * 4); // 4 个顶点
    
    self.vertices[0] = (SenceVertex){{-1, 1, 0}, {0, 1}}; // 左上角
    self.vertices[1] = (SenceVertex){{-1, -1, 0}, {0, 0}}; // 左下角
    self.vertices[2] = (SenceVertex){{1, 1, 0}, {1, 1}}; // 右上角
    self.vertices[3] = (SenceVertex){{1, -1, 0}, {1, 0}}; // 右下角
}

- (void)genBuffers {
    
    GLuint renderBuffer;
    GLuint frameBuffer;
    
    glGenRenderbuffers(1, &renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.layer];
    
    
    
    glGenFramebuffers(1, &frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER,
                              GL_COLOR_ATTACHMENT0,
                              GL_RENDERBUFFER,
                              renderBuffer);
}

- (void)genTexture {
    
    UIImage *image = [UIImage imageNamed:@"test123"];
    GLuint textureID = [self createTextureWithImage:image];
    
    glViewport(0, 0, self.drawableWidth, self.drawableHeight);
    
    // 编译链接 shader
    GLuint program = [self programWithShaderName:@"glsl"]; // glsl.vsh & glsl.fsh
    glUseProgram(program);
    
    // 获取 shader 中的参数，然后传数据进去
    GLuint positionSlot = glGetAttribLocation(program, "Position");
    GLuint textureSlot = glGetUniformLocation(program, "Texture");  // 注意 Uniform 类型的获取方式
    GLuint textureCoordsSlot = glGetAttribLocation(program, "TextureCoords");
    
    // 将纹理 ID 传给着色器程序
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, textureID);
    glUniform1i(textureSlot, 0);  // 将 textureSlot 赋值为 0，而 0 与 GL_TEXTURE0 对应，这里如果写 1，上面也要改成 GL_TEXTURE1
    
    // 创建顶点缓存
    GLuint vertexBuffer;
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    GLsizeiptr bufferSizeBytes = sizeof(SenceVertex) * 4;
    glBufferData(GL_ARRAY_BUFFER, bufferSizeBytes, self.vertices, GL_STATIC_DRAW);
    
    // 设置顶点数据
    glEnableVertexAttribArray(positionSlot);
    glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(SenceVertex), NULL + offsetof(SenceVertex, positionCoord));
    
    // 设置纹理数据
    glEnableVertexAttribArray(textureCoordsSlot);
    glVertexAttribPointer(textureCoordsSlot, 2, GL_FLOAT, GL_FALSE, sizeof(SenceVertex), NULL + offsetof(SenceVertex, textureCoord));
    
    // 开始绘制
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    // 将绑定的渲染缓存呈现到屏幕上
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
    
    // 删除顶点缓存
    glDeleteBuffers(1, &vertexBuffer);
    vertexBuffer = 0;
}

- (GLuint)programWithShaderName:(NSString *)shaderName {
    // 编译两个着色器
    GLuint vertexShader = [self compileShaderWithName:shaderName type:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self compileShaderWithName:shaderName type:GL_FRAGMENT_SHADER];
    
    // 挂载 shader 到 program 上
    GLuint program = glCreateProgram();
    glAttachShader(program, fragmentShader);
    glAttachShader(program, vertexShader);
   
    
    // 链接 program
    glLinkProgram(program);
    
    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);
    
    // 检查链接是否成功
    GLint linkSuccess;
    glGetProgramiv(program, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(program, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSAssert(NO, @"program链接失败：%@", messageString);
        exit(1);
    }
    return program;
}

// 编译一个 shader，并返回 shader 的 id
- (GLuint)compileShaderWithName:(NSString *)name type:(GLenum)shaderType {
    // 查找 shader 文件
    NSString *shaderPath = [[NSBundle mainBundle] pathForResource:name ofType:shaderType == GL_VERTEX_SHADER ? @"vsh" : @"fsh"]; // 根据不同的类型确定后缀名
    NSError *error;
    NSString *shaderString = [NSString stringWithContentsOfFile:shaderPath encoding:NSUTF8StringEncoding error:&error];
    if (!shaderString) {
        NSAssert(NO, @"读取shader失败");
        exit(1);
    }
    
    // 创建一个 shader 对象
    GLuint shader = glCreateShader(shaderType);
    
    // 获取 shader 的内容
    const char *shaderStringUTF8 = [shaderString UTF8String];
    int shaderStringLength = (int)[shaderString length];
    glShaderSource(shader, 1, &shaderStringUTF8, &shaderStringLength);
    
    // 编译shader
    glCompileShader(shader);
    
    // 查询 shader 是否编译成功
    GLint compileSuccess;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shader, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSAssert(NO, @"shader编译失败：%@", messageString);
        exit(1);
    }
    
    return shader;
}

- (GLuint)createTextureWithImage:(UIImage *)image {
    // 将 UIImage 转换为 CGImageRef
    CGImageRef cgImageRef = [image CGImage];
    GLuint width = (GLuint)CGImageGetWidth(cgImageRef);
    GLuint height = (GLuint)CGImageGetHeight(cgImageRef);
    CGRect rect = CGRectMake(0, 0, width, height);
    
    // 绘制图片
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    void *imageData = malloc(width * height * 4);
    CGContextRef context = CGBitmapContextCreate(imageData, width, height, 8, width * 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, 1.0f, -1.0f);
    CGColorSpaceRelease(colorSpace);
    CGContextClearRect(context, rect);
    CGContextDrawImage(context, rect, cgImageRef);
    
    // 生成纹理
    GLuint textureID;
    glGenTextures(1, &textureID);
    glBindTexture(GL_TEXTURE_2D, textureID);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData); // 将图片数据写入纹理缓存
    
    // 设置如何把纹素映射成像素
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    // 解绑
    glBindTexture(GL_TEXTURE_2D, 0);
    
    // 释放内存
    CGContextRelease(context);
    free(imageData);
    
    return textureID;
}

// 获取渲染缓存宽度 （单位是像素）
- (GLint)drawableWidth {
    GLint backingWidth;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    
    return backingWidth;
}

// 获取渲染缓存高度 （单位是像素）
- (GLint)drawableHeight {
    GLint backingHeight;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    
    return backingHeight;
}


@end
