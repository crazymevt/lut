(in-package #:lui-gtk-demo)
(defclass suggested-action (lui:button) ())
(defclass destructive-action (lui:button) ())
(defclass flat-action (lui:button) ())
(defdemo "theming_style_classes" "Semantic widget subclasses drive suggested/destructive/flat styling, hover/pressed rules and inherited light/dark palettes."
 (let ((r (app "Style classes" (node 'suggested-action :save :text "Suggested: Save")
               (node 'destructive-action :delete :text "Destructive: Delete")
               (node 'flat-action :flat :text "Flat action")
               (node 'lui:check-button :linked :text "Linked controls")
               (labeled :status "Hover, press, focus and disable controls"))))
  (setf (lui:style-rules r)
   '((:class suggested-action :style (:background :green :foreground :white :border-radius 0.3))
     (:class suggested-action :state :hover :style (:background :lime))
     (:class destructive-action :style (:background :maroon :foreground :white))
     (:class destructive-action :state :pressed :style (:background :red))
     (:class flat-action :style (:border-width 0 :background (0 0 0 0)))))
  (add-action r :theme "Light / dark" (lambda () (setf (lui:theme r) (if (eq (lui:theme r) lui:*dark-theme*) lui:*light-theme* lui:*dark-theme*))))
  (add-action r :disable "Disable / enable destructive action" (lambda () (setf (lui:enabled-p (control r :delete)) (not (lui:enabled-p (control r :delete)))))) r)
 (assert (eq :green (lui:style-value (control root :save) :background)))
 (setf (lui::hovered-p (control root :save)) t) (assert (eq :lime (lui:style-value (control root :save) :background)))
 (press root :theme) (assert (eq lui:*dark-theme* (lui:theme root)))
 (press root :disable) (assert (not (lui:enabled-p (control root :delete)))))
(defparameter *blur-shader*
 "#version 330
in vec2 fragTexCoord;
in vec4 fragColor;
uniform sampler2D texture0;
uniform float iTime;
uniform vec3 iResolution;
out vec4 finalColor;
void main(){vec2 uv=fragTexCoord;vec4 col=texture(texture0,uv);
if(uv.y<0.28||uv.y>0.72){vec4 sum=vec4(0);float r=iTime/640.0;
for(int x=-2;x<=2;x++)for(int y=-2;y<=2;y++)sum+=texture(texture0,uv+vec2(x,y)*r);
col=mix(sum/25.0,vec4(1,1,1,1),0.35);}finalColor=col*fragColor;}")
(defdemo "transparent" "Translucent overlays blur the image behind their top/bottom regions with adjustable sampling radius."
 (graphic-root "Transparency and blur" :transparent
  (lambda (c) (let ((r (scene-root c)))
   (list (op :shader *blur-shader* (state r :blur) 640 340 (sample-image))
         (op :rect 0 0 640 90 (list 255 255 255 (round (* 255 (state r :opacity)))))
         (op :rect 0 250 640 90 (list 255 255 255 (round (* 255 (state r :opacity)))))
         (op :text "Translucent overlay over blurred background" 30 35 22 :black)
         (op :text "Clear image remains visible in the middle" 30 280 22 :black))))
  :controls '((:blur "Blur radius" 0 20 5) (:opacity "Overlay opacity" 0 1 0.3)))
 (set-number root :blur 12) (assert (= 12 (third (first (operations root)))) )
 (set-number root :opacity 0.5) (assert (= 128 (fourth (car (last (second (operations root))))))))
