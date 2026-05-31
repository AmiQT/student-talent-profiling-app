import { supabase } from "../lib/supabase";

export interface RiskPrediction {
    student_id: string;
    risk_level: 'HIGH' | 'MEDIUM' | 'LOW';
    risk_score: number;
    confidence: number;
    current_cgpa: number;
    kokurikulum_score: number;
    risk_factors: string[];
    strengths: string[];
    recommendations: string[];
    gemini_insights?: {
        risk_score: number;
        confidence: number;
        recommendations: string[];
    };
}

export interface MLHealthStatus {
    success: boolean;
    model?: string;
    version?: string;
    lastCheck?: Date;
    error?: string;
}

class MLAnalyticsService {
    private baseUrl: string;

    constructor() {
        this.baseUrl = import.meta.env.PUBLIC_BACKEND_URL || "http://localhost:8000";
    }

    async checkHealth(): Promise<MLHealthStatus> {
        try {
            const response = await fetch(`${this.baseUrl}/api/ml/health`);
            if (!response.ok) throw new Error("Health check failed");

            const data = await response.json();
            return {
                success: data.status === "healthy",
                model: data.model || "Unknown",
                lastCheck: new Date()
            };
        } catch (error) {
            console.error("ML Service Health Check Failed:", error);
            return {
                success: false,
                model: "Offline",
                lastCheck: new Date()
            };
        }
    }

    async batchPredict(studentIds: string[]): Promise<{ success: boolean; data?: { results: RiskPrediction[] }; error?: string }> {
        try {
            const response = await fetch(`${this.baseUrl}/api/ml/batch/predict`, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                },
                body: JSON.stringify({ student_ids: studentIds }),
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.detail || "Batch prediction failed");
            }

            const data = await response.json();
            console.log("DEBUG: Raw API Response:", JSON.stringify(data, null, 2)); // Debug log
            return {
                success: true,
                data: {
                    results: data.results.map((r: any) => {
                        // Calculate actual CGPA from performance_metrics if needed
                        // performance_metrics.cgpa is normalized (0-1), multiply by 4 to get actual CGPA
                        const pm = r.performance_metrics || {};
                        const actualCgpa = r.current_cgpa || (pm.cgpa ? pm.cgpa * 4.0 : 0);
                        const actualKoku = r.kokurikulum_score || pm.koku_score || 0;

                        console.log(`DEBUG: Student ${r.display_id || r.student_id}: CGPA=${actualCgpa}, Koku=${actualKoku}`);

                        return {
                            student_id: r.display_id || r.student_id, // Prefer display_id (matric no)
                            display_id: r.display_id,
                            risk_score: r.risk_score,
                            risk_level: r.risk_level ? r.risk_level.toUpperCase() : 'LOW',
                            confidence: r.confidence,
                            risk_factors: r.risk_factors || [],
                            strengths: r.strengths || [],
                            recommendations: r.recommendations || [],
                            current_cgpa: actualCgpa,
                            kokurikulum_score: actualKoku,
                            gemini_insights: r.gemini_insights
                        };
                    })
                }
            };
        } catch (error: any) {
            console.error("Batch Prediction Failed:", error);
            return {
                success: false,
                error: error.message || "Failed to connect to ML Service"
            };
        }
    }

    formatRiskScore(score: number) {
        if (score >= 0.7) {
            return { level: 'HIGH', color: 'red', icon: '🔴', bgClass: 'bg-red-100 text-red-800' };
        } else if (score >= 0.4) {
            return { level: 'MEDIUM', color: 'yellow', icon: '🟡', bgClass: 'bg-yellow-100 text-yellow-800' };
        } else {
            return { level: 'LOW', color: 'green', icon: '🟢', bgClass: 'bg-green-100 text-green-800' };
        }
    }

    async generateInterventionPlan(studentId: string, extraContext: any = {}): Promise<{ success: boolean; plan?: string; error?: string }> {
        try {
            // Get session token
            const { data: { session } } = await supabase.auth.getSession();
            const token = session?.access_token;

            if (!token) {
                console.warn("No auth token found, attempting request without it (dev mode fallback)");
            }

            const headers: HeadersInit = {
                "Content-Type": "application/json",
            };

            if (token) {
                headers["Authorization"] = `Bearer ${token}`;
            }

            const response = await fetch(`${this.baseUrl}/api/ai/v2/command`, {
                method: "POST",
                headers,
                body: JSON.stringify({
                    command: `Based on the following STUDENT DATA provided in the context (do not query the database), generate a granular Academic Intervention Plan:
                    
                    Student Data:
                    - Risk Level: ${extraContext.risk_level || 'Unknown'}
                    - Risk Score: ${extraContext.risk_score || 'N/A'}
                    - CGPA: ${extraContext.current_cgpa || 'N/A'}
                    - Koku Score: ${extraContext.kokurikulum_score || 'N/A'}
                    - Factors: ${JSON.stringify(extraContext.risk_factors || [])}
                    
                    Task:
                    1. Analyze the specific risk factors.
                    2. Suggest 3 immediate actions for the student.
                    3. Suggest 2 actions for the Academic Advisor.
                    4. Create a 4-week recovery timeline.
                    
                    Tone: Constructive, encouraging, and professional.`,
                    context: {
                        student_id: studentId,
                        ...extraContext
                    }
                }),
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.detail || "Plan generation failed");
            }

            const data = await response.json();
            return {
                success: true,
                plan: data.message
            };
        } catch (error: any) {
            console.error("Plan Generation Failed:", error);
            return {
                success: false,
                error: error.message || "Failed to generate plan"
            };
        }
    }
}

export const mlAnalyticsService = new MLAnalyticsService();
