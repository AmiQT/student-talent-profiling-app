import { supabase } from "../lib/supabase";

export interface ActionPlan {
    studentId: string;
    riskLevel: string;
    recommendations: string[];
    interventionPlan: string;
}

export interface ActionPlanResult {
    success: boolean;
    plan?: ActionPlan;
    error?: string;
}

class GeminiService {
    private backendUrl: string;

    constructor() {
        this.backendUrl = import.meta.env.PUBLIC_BACKEND_URL || "http://localhost:8000";
    }

    async generateActionPlan(studentData: any): Promise<ActionPlanResult> {
        try {
            const { data: { session } } = await supabase.auth.getSession();
            if (!session) {
                return { success: false, error: "Not authenticated. Please log in." };
            }

            const riskLevel = studentData.risk_level || "UNKNOWN";
            const riskFactors = studentData.risk_factors || [];
            const strengths = studentData.strengths || [];
            const metrics = studentData.performance_metrics || {};

            const prompt = `
                Anda adalah penasihat akademik universiti Malaysia. Analisis data pelajar dan beri pelan tindakan ringkas.

                Data Pelajar:
                - ID: ${studentData.student_id}
                - Tahap Risiko: ${riskLevel}
                - Skor Risiko: ${(studentData.risk_score * 100).toFixed(1)}%
                - Kekuatan: ${strengths.length > 0 ? strengths.join(", ") : "Tiada data"}
                - Faktor Risiko: ${riskFactors.length > 0 ? riskFactors.join(", ") : "Tiada isu"}
                - Metrik: CGPA=${metrics.cgpa_normalized?.toFixed(2) || "N/A"}, Koku=${metrics.koku_normalized?.toFixed(2) || "N/A"}

                ARAHAN:
                1. Respons dalam Bahasa Melayu
                2. Fokus HANYA pada prestasi akademik (CGPA) dan kokurikulum
                3. Beri 2-3 cadangan praktikal sahaja
                4. Jangan sebut "0 CGPA" atau "0% attendance" - guna data sebenar di atas

                Beri respons JSON:
                {
                    "recommendations": ["cadangan1", "cadangan2"],
                    "interventionPlan": "Ringkasan pelan tindakan dalam 1-2 ayat."
                }
                Return ONLY valid JSON.
            `;

            const res = await fetch(`${this.backendUrl}/api/ai/v3/command`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    "Authorization": `Bearer ${session.access_token}`,
                },
                body: JSON.stringify({
                    command: prompt,
                    context: { source: "web_dashboard", student_id: studentData.student_id },
                }),
            });

            if (!res.ok) {
                const err = await res.text();
                return { success: false, error: `Backend error ${res.status}: ${err}` };
            }

            const data = await res.json();
            const text: string = data.response || "";

            const jsonStr = text.replace(/```json/g, "").replace(/```/g, "").trim();
            const parsed = JSON.parse(jsonStr);

            return {
                success: true,
                plan: {
                    studentId: studentData.student_id,
                    riskLevel: studentData.risk_level,
                    recommendations: parsed.recommendations || [],
                    interventionPlan: parsed.interventionPlan || "No plan generated.",
                },
            };
        } catch (error: any) {
            console.error("Error generating AI action plan:", error);
            return { success: false, error: error.message || "Failed to generate plan." };
        }
    }
}

export const geminiService = new GeminiService();
