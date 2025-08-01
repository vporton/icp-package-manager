import { Principal } from "@dfinity/principal";
import { useState } from "react";

export default function DisplayPrincipal(props: {value: Principal | undefined}) {
    const [copied, setCopied] = useState(false);
    
    if (props.value === undefined || props.value.isAnonymous()) {
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
            console.error('Failed to copy principal:', err);
        }
    };
    
    return (
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <code>{start}&hellip;{end}</code>
            <button 
                onClick={handleCopy}
                style={{
                    background: 'none',
                    border: '1px solid #ccc',
                    borderRadius: '4px',
                    padding: '2px 6px',
                    fontSize: '12px',
                    cursor: 'pointer',
                    color: copied ? '#28a745' : '#666'
                }}
                title="Copy principal to clipboard"
            >
                {copied ? 'Copied!' : 'Copy'}
            </button>
        </div>
    );
}