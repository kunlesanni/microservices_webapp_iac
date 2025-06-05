import React, { useState, useEffect } from 'react';
import { ChartBarIcon, CheckCircleIcon, ClockIcon, ListBulletIcon } from '@heroicons/react/24/outline';

function Stats({ apiBase }) {
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const response = await fetch(`${apiBase}/stats`);
        if (!response.ok) throw new Error('Failed to fetch statistics');
        const data = await response.json();
        setStats(data);
      } catch (err) {
        setError(err.message);
      } finally {
        setLoading(false);
      }
    };

    fetchStats();
  }, [apiBase]);

  if (loading) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-red-50 border border-red-200 rounded-md p-4">
        <div className="text-sm text-red-600">Error loading statistics: {error}</div>
      </div>
    );
  }

  const statItems = [
    {
      name: 'Total Tasks',
      value: stats.total_tasks,
      icon: ListBulletIcon,
      color: 'bg-blue-500'
    },
    {
      name: 'Completed',
      value: stats.completed_tasks,
      icon: CheckCircleIcon,
      color: 'bg-green-500'
    },
    {
      name: 'Pending',
      value: stats.pending_tasks,
      icon: ClockIcon,
      color: 'bg-yellow-500'
    },
    {
      name: 'Completion Rate',
      value: `${stats.completion_rate}%`,
      icon: ChartBarIcon,
      color: 'bg-purple-500'
    }
  ];

  return (
    <div>
      <div className="mb-6">
        <h2 className="text-2xl font-bold text-gray-900">Statistics</h2>
        <p className="text-gray-600">Overview of your task management progress</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {statItems.map((item) => (
          <div key={item.name} className="bg-white overflow-hidden shadow rounded-lg">
            <div className="p-5">
              <div className="flex items-center">
                <div className="flex-shrink-0">
                  <div className={`${item.color} rounded-md p-3`}>
                    <item.icon className="h-6 w-6 text-white" aria-hidden="true" />
                  </div>
                </div>
                <div className="ml-5 w-0 flex-1">
                  <dl>
                    <dt className="text-sm font-medium text-gray-500 truncate">
                      {item.name}
                    </dt>
                    <dd className="text-lg font-medium text-gray-900">
                      {item.value}
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>

      {stats.total_tasks > 0 && (
        <div className="mt-8 bg-white shadow rounded-lg p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Progress Overview</h3>
          <div className="w-full bg-gray-200 rounded-full h-4">
            <div
              className="bg-green-600 h-4 rounded-full transition-all duration-300"
              style={{ width: `${stats.completion_rate}%` }}
            ></div>
          </div>
          <p className="mt-2 text-sm text-gray-600">
            You've completed {stats.completed_tasks} out of {stats.total_tasks} tasks
          </p>
        </div>
      )}
    </div>
  );
}

export default Stats;
