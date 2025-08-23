import { Principal } from "@dfinity/principal";
import React, { useState } from "react";

export default function DisplayPrincipal(props: {value: Principal | undefined}) {
    const [copied, setCopied] = useState(false);
    
    if (props.value === undefined) {
        return "";
    }
    
    const s = props.value.toString();
    const start = s.substring(0, 6);
    const end = s.substring(s.length - 4);
    
    const handleCopy = async () => {
        try {
            await navigator.clipboard.writeText(s);
            setCopied(true);
            setTimeout(() => setCopied(false), 2000);
        } catch (err) {
            console.error('Failed to copy principal to clipboard:', err);
        }
    };
    
    return (
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: '8px' }}>
            <code>{s.length > 11 ? <>{start}&hellip;{end}</> : s}</code> {/* FIXME@P3: Is the condition correct? */}
            <button 
                onClick={handleCopy}
                style={{
                    background: 'none',
                    border: '1px solid #ccc',
                    borderRadius: '4px',
                    padding: '2px 6px',
                    fontSize: '12px',
                    cursor: 'pointer',
                    color: copied ? '#4CAF50' : '#666'
                }}
                title="Copy full principal to clipboard"
            >
                {copied ? 'Copied!' : 'Copy'}
            </button>
        </div>
    );
} 