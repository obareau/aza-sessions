#!/usr/bin/env python3
"""
Revue de code locale via qwen2.5-coder (Ollama).

Usage :
  git diff | python scripts/ai_review.py          # diff non-stagé
  git diff --cached | python scripts/ai_review.py  # diff stagé
  git diff HEAD~1 | python scripts/ai_review.py    # dernier commit
"""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from core.ollama_client import review_diff

diff = sys.stdin.read()
print(review_diff(diff))
