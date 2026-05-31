"""Template-based generators untuk pseudo AI outputs."""

from __future__ import annotations

from datetime import datetime
from typing import Any


def generate_student_report_summary(data: dict[str, Any] | None = None) -> dict[str, Any]:
    """Generate summary template untuk laporan pelajar."""

    now = datetime.utcnow()

    return {
        "generated_at": now.isoformat() + "Z",
        "title": "Semester Performance Overview",
        "highlights": [
            "Top performing departments: Computer Science, Data Science",
            "Overall engagement stable dengan +6% peningkatan event participation",
            "15 students flagged for academic support follow-up",
        ],
        "recommendations": [
            "Jalankan sesi kaunseling targeted untuk pelajar berisiko",
            "Teruskan program mentorship sebab impact engagement positif",
            "Highlight success stories dalam newsletter fakulti",
        ],
        "raw_context": data or {},
    }


def generate_search_placeholder(query: str) -> dict[str, Any]:
    """Placeholder data untuk search sebelum integrasi penuh."""

    return {
        "query": query,
        "suggestions": [
            "Gunakan filter department untuk refine results",
            "Cuba tambah kata kunci seperti 'inactive' atau '2024'",
        ],
        "results": [],
    }


def generate_user_creation_summary(students: list[dict[str, Any]]) -> dict[str, Any]:
    """Summarize student generation output."""

    departments = {}
    for student in students:
        dept = student.get("department", "Unknown")
        departments[dept] = departments.get(dept, 0) + 1

    return {
        "total_created": len(students),
        "distribution": departments,
        "next_steps": [
            "Review senarai yang dijana dan edit jika perlu",
            "Eksport ke CSV atau terus import dalam Supabase",
            "Trigger welcome email automation (manual buat masa sekarang)",
        ],
    }

