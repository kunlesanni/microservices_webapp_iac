import React, { useState } from 'react';
import { CheckIcon, XMarkIcon, PencilIcon } from '@heroicons/react/24/outline';

function TaskItem({ task, onUpdate, onDelete }) {
  const [isEditing, setIsEditing] = useState(false);
  const [editTitle, setEditTitle] = useState(task.title);
  const [editDescription, setEditDescription] = useState(task.description || '');

  const handleToggleComplete = () => {
    onUpdate(task.id, { completed: !task.completed });
  };

  const handleSave = () => {
    onUpdate(task.id, { 
      title: editTitle, 
      description: editDescription 
    });
    setIsEditing(false);
  };

  const handleCancel = () => {
    setEditTitle(task.title);
    setEditDescription(task.description || '');
    setIsEditing(false);
  };

  return (
    <div className="bg-white shadow rounded-lg p-6 hover:shadow-md transition-shadow">
      <div className="flex items-start justify-between">
        <div className="flex items-start space-x-3 flex-1">
          <button
            onClick={handleToggleComplete}
            className={`mt-1 flex-shrink-0 w-5 h-5 rounded border-2 flex items-center justify-center transition-colors ${
              task.completed
                ? 'bg-green-500 border-green-500 text-white'
                : 'border-gray-300 hover:border-green-400'
            }`}
          >
            {task.completed && <CheckIcon className="w-3 h-3" />}
          </button>

          <div className="flex-1">
            {isEditing ? (
              <div className="space-y-3">
                <input
                  type="text"
                  value={editTitle}
                  onChange={(e) => setEditTitle(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="Task title"
                />
                <textarea
                  value={editDescription}
                  onChange={(e) => setEditDescription(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="Task description"
                  rows="3"
                />
                <div className="flex space-x-2">
                  <button
                    onClick={handleSave}
                    className="px-3 py-1 bg-blue-500 text-white text-sm rounded hover:bg-blue-600"
                  >
                    Save
                  </button>
                  <button
                    onClick={handleCancel}
                    className="px-3 py-1 bg-gray-300 text-gray-700 text-sm rounded hover:bg-gray-400"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            ) : (
              <div>
                <h3 className={`text-lg font-medium ${
                  task.completed ? 'line-through text-gray-500' : 'text-gray-900'
                }`}>
                  {task.title}
                </h3>
                {task.description && (
                  <p className={`mt-1 text-sm ${
                    task.completed ? 'line-through text-gray-400' : 'text-gray-600'
                  }`}>
                    {task.description}
                  </p>
                )}
                <p className="mt-2 text-xs text-gray-400">
                  Created: {new Date(task.created_at).toLocaleDateString()}
                </p>
              </div>
            )}
          </div>
        </div>

        {!isEditing && (
          <div className="flex space-x-2">
            <button
              onClick={() => setIsEditing(true)}
              className="p-1 text-gray-400 hover:text-blue-500"
            >
              <PencilIcon className="w-4 h-4" />
            </button>
            <button
              onClick={() => onDelete(task.id)}
              className="p-1 text-gray-400 hover:text-red-500"
            >
              <XMarkIcon className="w-4 h-4" />
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

function TaskList({ tasks, loading, onUpdateTask, onDeleteTask }) {
  const [filter, setFilter] = useState('all');

  const filteredTasks = tasks.filter(task => {
    if (filter === 'completed') return task.completed;
    if (filter === 'pending') return !task.completed;
    return true;
  });

  if (loading) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500"></div>
      </div>
    );
  }

  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-2xl font-bold text-gray-900">Tasks</h2>
        <div className="flex space-x-2">
          {['all', 'pending', 'completed'].map(filterType => (
            <button
              key={filterType}
              onClick={() => setFilter(filterType)}
              className={`px-3 py-1 rounded text-sm capitalize ${
                filter === filterType
                  ? 'bg-blue-500 text-white'
                  : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
              }`}
            >
              {filterType}
            </button>
          ))}
        </div>
      </div>

      {filteredTasks.length === 0 ? (
        <div className="text-center py-12">
          <div className="text-gray-400 text-lg">
            {tasks.length === 0 ? 'No tasks yet.' : `No ${filter} tasks.`}
          </div>
          <p className="text-gray-500 mt-2">
            {tasks.length === 0 ? 'Create your first task to get started!' : 'Try a different filter.'}
          </p>
        </div>
      ) : (
        <div className="space-y-4">
          {filteredTasks.map(task => (
            <TaskItem
              key={task.id}
              task={task}
              onUpdate={onUpdateTask}
              onDelete={onDeleteTask}
            />
          ))}
        </div>
      )}
    </div>
  );
}

export default TaskList;