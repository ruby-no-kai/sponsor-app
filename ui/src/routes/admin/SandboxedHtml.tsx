import { useEffect, useRef, useState } from "react";

// Staff-authored HTML, which Markdown lets carry raw HTML. The sandbox runs no script, so the
// frame may share this origin to have its height read. Links open in a new tab. Headings are scaled
// for the 14px text of the page around it.
export function SandboxedHtml({ html, title }: { html: string; title: string }) {
  const frameRef = useRef<HTMLIFrameElement>(null);
  const [height, setHeight] = useState<number>();

  useEffect(() => {
    const frame = frameRef.current;
    if (frame === null) return;
    // The root's box holds the margins that collapse through body, which body.scrollHeight omits.
    const measure = () => {
      const root = frame.contentDocument?.documentElement;
      if (root !== undefined && root !== null) {
        setHeight(Math.ceil(root.getBoundingClientRect().height));
      }
    };
    const onLoad = () => {
      measure();
      frame.contentDocument?.addEventListener("load", measure, { capture: true });
    };
    // Lines wrap anew as the frame's width changes.
    const observer = new ResizeObserver(measure);
    observer.observe(frame);
    frame.addEventListener("load", onLoad);
    return () => {
      observer.disconnect();
      frame.removeEventListener("load", onLoad);
    };
  }, []);

  return (
    <iframe
      ref={frameRef}
      sandbox="allow-same-origin allow-popups allow-popups-to-escape-sandbox"
      srcDoc={`<!doctype html><base target="_blank"><style>:root{color-scheme:light dark}body{margin:0;font:14px/1.5 system-ui,sans-serif;overflow-wrap:anywhere}h1,h2,h3,h4,h5,h6{font-weight:600;line-height:1.3}h1{font-size:20px}h2{font-size:16px}h3,h4,h5,h6{font-size:14px}img{max-width:100%;height:auto}</style>${html}`}
      title={title}
      className="block w-full border-0"
      style={{ height: height === undefined ? "3rem" : `${height}px` }}
    />
  );
}
