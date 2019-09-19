precision mediump float;

uniform sampler2D Texture;
varying vec2 TextureCoordsVarying;

void main (void) {
     vec4 mask = texture2D(Texture, TextureCoordsVarying);
     float gray = mask.r * 0.299 + mask.g * 0.587 + mask.b * 0.114;
     gl_FragColor = vec4(gray, gray, gray, 1.0);
}


