import { useEffect, useRef, useState } from "react";
import { markPlaceholders } from "./placeholders.ts";

// Staff-authored HTML, which Markdown lets carry raw HTML. The sandbox runs no script, so the
// frame may share this origin to have its height read. Links open in a new tab. Headings are
// scaled for the 14px text of the page around it, or smaller with `compact`. `placeholders` are
// tokens shown marked, as they are not text the reader sees.
export function SandboxedHtml({
  html,
  title,
  compact = false,
  placeholders = [],
}: {
  html: string;
  title: string;
  compact?: boolean;
  placeholders?: readonly string[];
}) {
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
      srcDoc={`<!doctype html><base target="_blank"><style>:root{color-scheme:light dark}body{margin:0;font:14px/1.5 system-ui,sans-serif;overflow-wrap:anywhere}h1,h2,h3,h4,h5,h6{font-weight:600;line-height:1.3}h1{font-size:${compact ? 18 : 20}px}h2{font-size:${compact ? 15 : 16}px}h3,h4,h5,h6{font-size:14px}mark{border-radius:3px;padding:0 3px;font:12px ui-monospace,monospace;background:color-mix(in srgb,currentColor 14%,transparent);color:inherit}img{max-width:100%;height:auto}</style>${markPlaceholders(html, placeholders)}`}
      title={title}
      className="block w-full border-0"
      style={{ height: height === undefined ? "3rem" : `${height}px` }}
    />
  );
}
